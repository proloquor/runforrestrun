import Foundation

/// Pure functions that turn a `UserProfile` into concrete zone boundaries and
/// classify a live BPM into a zone. Uses Heart Rate Reserve (Karvonen).
enum ZoneCalculator {
    /// BPM range for a zone given the profile.
    static func bpmRange(for zone: HeartRateZone, profile: UserProfile) -> ClosedRange<Int> {
        HeartRateTarget.zone(zone).bpmRange(for: profile)
    }

    /// All five zones with their BPM ranges, low → high.
    static func allZoneRanges(profile: UserProfile) -> [(zone: HeartRateZone, range: ClosedRange<Int>)] {
        HeartRateZone.allCases.map { ($0, bpmRange(for: $0, profile: profile)) }
    }

    /// Which zone a given BPM falls into (nil if below Zone 1).
    static func zone(forBPM bpm: Int, profile: UserProfile) -> HeartRateZone? {
        for zone in HeartRateZone.allCases.reversed() {
            let range = bpmRange(for: zone, profile: profile)
            if bpm >= range.lowerBound { return zone }
        }
        return nil
    }

    /// Fraction of max HR a BPM represents (0...1+), for gauges.
    static func fractionOfMax(bpm: Int, profile: UserProfile) -> Double {
        Double(bpm) / Double(max(profile.maxHeartRate, 1))
    }
}
