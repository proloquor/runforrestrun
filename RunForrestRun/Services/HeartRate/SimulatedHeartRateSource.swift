import Foundation
import Combine

/// A deterministic fake HR signal so the app is fully usable in the simulator,
/// in SwiftUI previews, and before any hardware is paired. It gently drifts
/// toward a moving "effort" target so the workout engine's zone alerts actually
/// fire during a demo.
final class SimulatedHeartRateSource: HeartRateSource {
    let kind: HeartRateSourceKind = .simulated

    private let sampleSubject = PassthroughSubject<HeartRateSample, Never>()
    private let stateSubject = CurrentValueSubject<HeartRateConnectionState, Never>(.disconnected)

    private var timer: Timer?
    private var current: Double = 70
    private var tick: Int = 0

    var samples: AnyPublisher<HeartRateSample, Never> { sampleSubject.eraseToAnyPublisher() }
    var state: AnyPublisher<HeartRateConnectionState, Never> { stateSubject.eraseToAnyPublisher() }

    func start() {
        stateSubject.send(.connected(deviceName: "Demo"))
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        stateSubject.send(.disconnected)
    }

    private func advance() {
        tick += 1
        // A slow sawtooth of effort between ~65% and ~95% so we sweep across zones.
        let phase = Double(tick % 240) / 240.0
        let effort = 0.65 + 0.30 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
        let target = 60 + effort * 120 // maps to ~138–174 bpm
        // Ease toward target with a little jitter.
        let jitter = Double((tick * 37) % 7) - 3
        current += (target - current) * 0.15 + jitter * 0.4
        current = min(max(current, 48), 195)
        sampleSubject.send(HeartRateSample(bpm: Int(current.rounded()), timestamp: Date(), origin: .simulated))
    }
}
