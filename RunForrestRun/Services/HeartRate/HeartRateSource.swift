import Foundation
import Combine

enum HeartRateSourceKind: String, CaseIterable, Identifiable {
    case bluetooth
    case oura
    case simulated

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bluetooth: return "Bluetooth HR strap"
        case .oura: return "Oura (cloud)"
        case .simulated: return "Demo signal"
        }
    }

    var subtitle: String {
        switch self {
        case .bluetooth: return "Real-time · best for interval alerts"
        case .oura: return "Polls Oura cloud · a few seconds of lag"
        case .simulated: return "Fake data for trying the app out"
        }
    }
}

enum HeartRateConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(deviceName: String?)
    case unavailable(reason: String)

    var isLive: Bool {
        if case .connected = self { return true }
        return false
    }
}

/// A pluggable heart-rate provider. BLE, Oura polling and the simulator all
/// conform, so the rest of the app only ever talks to `HeartRateMonitor`.
protocol HeartRateSource: AnyObject {
    var kind: HeartRateSourceKind { get }
    var samples: AnyPublisher<HeartRateSample, Never> { get }
    var state: AnyPublisher<HeartRateConnectionState, Never> { get }
    func start()
    func stop()
}
