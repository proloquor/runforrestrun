import Foundation
import Combine

/// Streams heart rate by polling the Oura cloud API for the most recent sample.
///
/// IMPORTANT: This is not truly real-time. The ring buffers readings and syncs
/// them to Oura's servers through the phone periodically, so live samples lag by
/// seconds to a couple of minutes. It is fine for the Zone 2 run (steady effort)
/// but for the 4×4 we strongly recommend a Bluetooth strap. The UI surfaces this.
final class OuraLiveHeartRateSource: HeartRateSource {
    let kind: HeartRateSourceKind = .oura

    private let client: OuraClient
    private let pollInterval: TimeInterval
    private let sampleSubject = PassthroughSubject<HeartRateSample, Never>()
    private let stateSubject = CurrentValueSubject<HeartRateConnectionState, Never>(.disconnected)

    private var pollTask: Task<Void, Never>?
    private var lastEmittedTimestamp: Date?

    init(client: OuraClient, pollInterval: TimeInterval = 15) {
        self.client = client
        self.pollInterval = pollInterval
    }

    var samples: AnyPublisher<HeartRateSample, Never> { sampleSubject.eraseToAnyPublisher() }
    var state: AnyPublisher<HeartRateConnectionState, Never> { stateSubject.eraseToAnyPublisher() }

    func start() {
        guard pollTask == nil else { return }
        stateSubject.send(.connecting)
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        stateSubject.send(.disconnected)
    }

    private func pollLoop() async {
        // Token lives on the @MainActor client; read it across the actor boundary.
        guard await client.hasToken else {
            stateSubject.send(.unavailable(reason: "Connect your Oura account first"))
            return
        }
        while !Task.isCancelled {
            do {
                if let sample = try await client.latestHeartRate() {
                    // Only emit genuinely new samples.
                    if lastEmittedTimestamp != sample.timestamp {
                        lastEmittedTimestamp = sample.timestamp
                        stateSubject.send(.connected(deviceName: "Oura Ring"))
                        sampleSubject.send(sample)
                    }
                }
            } catch {
                stateSubject.send(.unavailable(reason: "Oura sync error"))
            }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }
}
