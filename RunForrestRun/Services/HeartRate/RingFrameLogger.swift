import Foundation
import Combine

/// Captures a rolling log of raw BLE frames and decode steps from the direct
/// Oura-ring source, so you can see exactly what the ring sends and calibrate the
/// protocol decoding. Newest entries first.
///
/// Deliberately not `@MainActor`: the BLE stack calls `append` from its delegate
/// thread, and we hop to main internally to publish. That keeps the call sites in
/// `OuraRingHeartRateSource` free of actor-isolation ceremony.
final class RingFrameLogger: ObservableObject {
    @Published private(set) var lines: [String] = []

    private let maxLines = 500
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func append(_ message: String) {
        let line = "\(formatter.string(from: Date()))  \(message)"
        DispatchQueue.main.async {
            self.lines.insert(line, at: 0)
            if self.lines.count > self.maxLines {
                self.lines.removeLast(self.lines.count - self.maxLines)
            }
        }
    }

    func clear() {
        DispatchQueue.main.async { self.lines.removeAll() }
    }

    /// Oldest → newest, for copy/share.
    var exportText: String { lines.reversed().joined(separator: "\n") }
}
