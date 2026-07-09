import Foundation

/// Talks to the Oura API v2 using a Personal Access Token (PAT).
///
/// Why a PAT rather than full OAuth? For a personal, single-user training app a
/// PAT is dramatically simpler: no backend, no redirect URI, no client secret.
/// You create one at https://cloud.ouraring.com/personal-access-tokens and paste
/// it into the Connect screen once. (OAuth 2.0 can be layered on later behind the
/// same `OuraClient` interface if this ever ships to multiple users.)
enum OuraError: LocalizedError {
    case notAuthenticated
    case unauthorized
    case http(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "No Oura token saved."
        case .unauthorized: return "Oura rejected the token. Check it and reconnect."
        case .http(let code): return "Oura request failed (HTTP \(code))."
        case .decoding: return "Couldn't read Oura's response."
        }
    }
}

@MainActor
final class OuraClient: ObservableObject {
    static let tokenKey = "oura.personal.access.token"
    private let baseURL = URL(string: "https://api.ouraring.com/v2")!
    private let session: URLSession

    @Published private(set) var isConnected: Bool

    init(session: URLSession = .shared) {
        self.session = session
        self.isConnected = Keychain.get(OuraClient.tokenKey) != nil
    }

    var hasToken: Bool { token != nil }
    private var token: String? { Keychain.get(OuraClient.tokenKey) }

    func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        Keychain.set(trimmed, for: OuraClient.tokenKey)
        isConnected = true
    }

    func disconnect() {
        Keychain.delete(OuraClient.tokenKey)
        isConnected = false
    }

    /// Validates the saved token by hitting the personal-info endpoint.
    @discardableResult
    func verifyConnection() async throws -> OuraPersonalInfo {
        try await get("usercollection/personal_info", as: OuraPersonalInfo.self)
    }

    func personalInfo() async throws -> OuraPersonalInfo {
        try await get("usercollection/personal_info", as: OuraPersonalInfo.self)
    }

    /// Most recent resting HR from the last few days of readiness data.
    func latestRestingHeartRate() async throws -> Int? {
        let end = ISO8601DateOnly.string(from: Date())
        let start = ISO8601DateOnly.string(from: Date().addingTimeInterval(-7 * 86_400))
        let response = try await get(
            "usercollection/daily_readiness?start_date=\(start)&end_date=\(end)",
            as: OuraDailyReadinessResponse.self
        )
        return response.data
            .sorted { $0.day > $1.day }
            .compactMap { $0.contributors?.restingHeartRate }
            .first
    }

    /// The newest heart-rate sample Oura has synced. Used by the live polling source.
    func latestHeartRate() async throws -> HeartRateSample? {
        // Ask for the last ~5 minutes; Oura returns them in ascending time order.
        let now = Date()
        let start = ISO8601Full.string(from: now.addingTimeInterval(-300))
        let end = ISO8601Full.string(from: now.addingTimeInterval(60))
        let path = "usercollection/heartrate?start_datetime=\(encode(start))&end_datetime=\(encode(end))"
        let response = try await get(path, as: OuraHeartRateResponse.self)
        guard let latest = response.data.last,
              let date = ISO8601Full.date(from: latest.timestamp)
                ?? ISO8601Fractional.date(from: latest.timestamp) else { return nil }
        return HeartRateSample(bpm: latest.bpm, timestamp: date, origin: .oura)
    }

    // MARK: - Networking

    private func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        guard let token else { throw OuraError.notAuthenticated }
        let url = baseURL.appendingPathComponent(path.components(separatedBy: "?").first ?? path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if let query = path.components(separatedBy: "?").dropFirst().first {
            components.percentEncodedQuery = query
        }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OuraError.http(-1) }
        switch http.statusCode {
        case 200...299:
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw OuraError.decoding }
        case 401, 403:
            throw OuraError.unauthorized
        default:
            throw OuraError.http(http.statusCode)
        }
    }

    private func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? s
    }
}

// MARK: - Date helpers

private enum ISO8601DateOnly {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func string(from date: Date) -> String { formatter.string(from: date) }
}

private enum ISO8601Full {
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static func string(from date: Date) -> String { formatter.string(from: date) }
    static func date(from string: String) -> Date? { formatter.date(from: string) }
}

private enum ISO8601Fractional {
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static func date(from string: String) -> Date? { formatter.date(from: string) }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "+:")
        return set
    }()
}
