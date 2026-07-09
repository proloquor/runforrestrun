import Foundation

/// A heart-rate target for a workout phase. It can be expressed three ways and
/// always resolves to a concrete BPM range for a given profile.
enum HeartRateTarget: Codable, Equatable {
    /// Stay inside a named zone (uses HRR boundaries).
    case zone(HeartRateZone)
    /// A fraction-of-max-HR band, e.g. 0.85...0.95 for the Norwegian 4x4 work bouts.
    case percentMax(ClosedRange<Double>)
    /// A fraction-of-HRR band (Karvonen).
    case percentHRR(ClosedRange<Double>)

    func bpmRange(for profile: UserProfile) -> ClosedRange<Int> {
        let maxHR = Double(profile.maxHeartRate)
        let rest = Double(profile.restingHeartRate)
        let reserve = max(maxHR - rest, 1)

        switch self {
        case .zone(let zone):
            let lo = rest + zone.hrrRange.lowerBound * reserve
            let hi = rest + zone.hrrRange.upperBound * reserve
            return Int(lo.rounded())...Int(hi.rounded())
        case .percentMax(let range):
            let lo = range.lowerBound * maxHR
            let hi = range.upperBound * maxHR
            return Int(lo.rounded())...Int(hi.rounded())
        case .percentHRR(let range):
            let lo = rest + range.lowerBound * reserve
            let hi = rest + range.upperBound * reserve
            return Int(lo.rounded())...Int(hi.rounded())
        }
    }

    var shortDescription: String {
        switch self {
        case .zone(let z): return z.name
        case .percentMax(let r):
            return "\(Int(r.lowerBound * 100))–\(Int(r.upperBound * 100))% max HR"
        case .percentHRR(let r):
            return "\(Int(r.lowerBound * 100))–\(Int(r.upperBound * 100))% HRR"
        }
    }
}

// MARK: - Codable (ClosedRange isn't Codable out of the box)

extension HeartRateTarget {
    private enum CodingKeys: String, CodingKey { case kind, zone, low, high }
    private enum Kind: String, Codable { case zone, percentMax, percentHRR }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .zone:
            self = .zone(try c.decode(HeartRateZone.self, forKey: .zone))
        case .percentMax:
            let lo = try c.decode(Double.self, forKey: .low)
            let hi = try c.decode(Double.self, forKey: .high)
            self = .percentMax(lo...hi)
        case .percentHRR:
            let lo = try c.decode(Double.self, forKey: .low)
            let hi = try c.decode(Double.self, forKey: .high)
            self = .percentHRR(lo...hi)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .zone(let z):
            try c.encode(Kind.zone, forKey: .kind)
            try c.encode(z, forKey: .zone)
        case .percentMax(let r):
            try c.encode(Kind.percentMax, forKey: .kind)
            try c.encode(r.lowerBound, forKey: .low)
            try c.encode(r.upperBound, forKey: .high)
        case .percentHRR(let r):
            try c.encode(Kind.percentHRR, forKey: .kind)
            try c.encode(r.lowerBound, forKey: .low)
            try c.encode(r.upperBound, forKey: .high)
        }
    }
}
