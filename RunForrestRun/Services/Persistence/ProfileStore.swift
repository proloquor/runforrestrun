import Foundation
import Combine

/// Persists the `UserProfile` to UserDefaults as JSON.
@MainActor
final class ProfileStore: ObservableObject {
    private let key = "user.profile.v1"
    private let defaults: UserDefaults

    @Published var profile: UserProfile {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.profile = decoded
        } else {
            self.profile = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: key)
        }
    }

    func updateRestingHeartRate(_ bpm: Int, source: UserProfile.MetricSource) {
        profile.restingHeartRate = bpm
        profile.restingHeartRateSource = source
    }

    func updateMaxHeartRate(_ bpm: Int, source: UserProfile.MetricSource) {
        profile.measuredMaxHeartRate = bpm
        profile.maxHeartRateSource = source
    }
}
