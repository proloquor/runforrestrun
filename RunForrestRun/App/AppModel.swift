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

        // Default to a Bluetooth strap on device; the simulator has no BLE so we
        // fall back to the demo signal there.
        #if targetEnvironment(simulator)
        let initialKind: HeartRateSourceKind = .simulated
        #else
        let initialKind: HeartRateSourceKind = .bluetooth
        #endif

        self.monitor = HeartRateMonitor(initialKind: initialKind) { kind in
            switch kind {
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
