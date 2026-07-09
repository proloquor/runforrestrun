import SwiftUI

/// The classic five-zone model. Boundaries here are expressed as a fraction of
/// Heart Rate Reserve (HRR / Karvonen), because we get a real resting heart rate
/// from Oura and HRR personalises the zones far better than a flat %HRmax split.
enum HeartRateZone: Int, CaseIterable, Identifiable, Codable {
    case zone1 = 1
    case zone2
    case zone3
    case zone4
    case zone5

    var id: Int { rawValue }

    /// Fraction-of-HRR range that defines the zone (lower inclusive, upper exclusive
    /// except Zone 5 which is capped at 1.0).
    var hrrRange: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.60
        case .zone2: return 0.60...0.70
        case .zone3: return 0.70...0.80
        case .zone4: return 0.80...0.90
        case .zone5: return 0.90...1.00
        }
    }

    var name: String {
        switch self {
        case .zone1: return "Zone 1"
        case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"
        case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    var label: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Aerobic base"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "VO₂ max"
        }
    }

    var color: Color {
        switch self {
        case .zone1: return Color(red: 0.42, green: 0.62, blue: 0.86) // blue
        case .zone2: return Color(red: 0.30, green: 0.72, blue: 0.55) // green
        case .zone3: return Color(red: 0.92, green: 0.76, blue: 0.30) // amber
        case .zone4: return Color(red: 0.92, green: 0.53, blue: 0.24) // orange
        case .zone5: return Color(red: 0.86, green: 0.30, blue: 0.34) // red
        }
    }
}
