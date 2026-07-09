import Foundation

/// Decodable shapes for the subset of the Oura API v2 we use.
/// Docs: https://cloud.ouraring.com/v2/docs

struct OuraPersonalInfo: Decodable {
    let age: Int?
    let weight: Double?
    let height: Double?
    let biologicalSex: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case age, weight, height, email
        case biologicalSex = "biological_sex"
    }
}

struct OuraHeartRateResponse: Decodable {
    let data: [OuraHeartRateSample]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case data
        case nextToken = "next_token"
    }
}

struct OuraHeartRateSample: Decodable {
    let bpm: Int
    let source: String        // "awake", "rest", "sleep", "session", "workout", "live"
    let timestamp: String     // ISO-8601
}

struct OuraDailyReadinessResponse: Decodable {
    let data: [OuraDailyReadiness]
}

struct OuraDailyReadiness: Decodable {
    let id: String
    let day: String
    let score: Int?
    let contributors: Contributors?

    struct Contributors: Decodable {
        let restingHeartRate: Int?
        let hrvBalance: Int?

        enum CodingKeys: String, CodingKey {
            case restingHeartRate = "resting_heart_rate"
            case hrvBalance = "hrv_balance"
        }
    }
}

struct OuraDailySleepResponse: Decodable {
    let data: [OuraDailySleep]
}

struct OuraDailySleep: Decodable {
    let id: String
    let day: String
    let averageHeartRate: Double?
    let lowestHeartRate: Int?

    enum CodingKeys: String, CodingKey {
        case id, day
        case averageHeartRate = "average_heart_rate"
        case lowestHeartRate = "lowest_heart_rate"
    }
}
