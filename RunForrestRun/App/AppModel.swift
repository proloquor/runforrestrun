import Foundation
import SwiftUI

/// Composition root. Owns the long-lived services and wires the heart-rate source
/// factory so `HeartRateMonitor` can build BLE / Oura / simulated sources on demand.
@MainActor
final class AppModel: ObservableObject {
    let profileStore: ProfileStore
    let historyStore: HistoryStore
    let ouraClient: OuraClient
    let coach: AudioCoach
    let monitor: HeartRateMonitor

    init() {
        let profileStore = ProfileStore()
        let historyStore = HistoryStore()
        let ouraClient = OuraClient()
        let coach = AudioCoach()

        self.profileStore = profileStore
        self.historyStore = historyStore
        self.ouraClient = ouraClient
        self.coach = coach

        // On device, prefer the direct Oura-ring source if the user has saved a ring
        // key; otherwise fall back to a Bluetooth strap. The simulator has no BLE, so
        // it uses the demo signal.
        #if targetEnvironment(simulator)
        let initialKind: HeartRateSourceKind = .simulated
        #else
        let hasRingKey = Keychain.get(OuraRingHeartRateSource.keychainKey) != nil
        let initialKind: HeartRateSourceKind = hasRingKey ? .ouraRing : .bluetooth
        #endif

        self.monitor = HeartRateMonitor(initialKind: initialKind) { kind in
            switch kind {
            case .ouraRing:
                let key = Keychain.get(OuraRingHeartRateSource.keychainKey).flatMap { Data(hexString: $0) }
                return OuraRingHeartRateSource(authKey: key)
            case .bluetooth: return BLEHeartRateSource()
            case .oura: return OuraLiveHeartRateSource(client: ouraClient)
            case .simulated: return SimulatedHeartRateSource()
            }
        }
    }

    /// Builds a fresh engine for a workout run.
    func makeEngine(for template: WorkoutTemplate) -> WorkoutEngine {
        WorkoutEngine(
            template: template,
            profile: profileStore.profile,
            monitor: monitor,
            coach: coach,
            historyStore: historyStore
        )
    }

    /// Pull resting HR (and age) from Oura into the local profile.
    func syncProfileFromOura() async {
        guard ouraClient.hasToken else { return }
        if let resting = try? await ouraClient.latestRestingHeartRate() {
            profileStore.updateRestingHeartRate(resting, source: .oura)
        }
        if let info = try? await ouraClient.personalInfo(), let age = info.age {
            profileStore.profile.age = age
        }
    }
}
