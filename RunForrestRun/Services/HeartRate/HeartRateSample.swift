import Foundation

/// A single heart-rate reading with its provenance.
struct HeartRateSample: Codable, Equatable, Identifiable {
    enum Origin: String, Codable {
        case ble          // real-time BLE strap / monitor
        case oura         // polled from the Oura cloud API (has latency)
        case simulated    // demo / preview
    }

    var id: Date { timestamp }
    let bpm: Int
    let timestamp: Date
    let origin: Origin
}
