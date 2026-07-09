import Foundation

/// Everything we need to personalise heart-rate zones. Resting HR is ideally
/// pulled from Oura; max HR is ideally *measured* with the in-app zone test,
/// falling back to an age-based estimate.
struct UserProfile: Codable, Equatable {
    var name: String
    var age: Int
    var restingHeartRate: Int
    /// User's measured/known max HR. When nil we estimate from age.
    var measuredMaxHeartRate: Int?
    /// Where `restingHeartRate` came from, for display honesty.
    var restingHeartRateSource: MetricSource
    var maxHeartRateSource: MetricSource

    enum MetricSource: String, Codable {
        case manual
        case oura
        case estimated
        case measured
    }

    /// Effective max HR used for all zone math.
    var maxHeartRate: Int {
        measuredMaxHeartRate ?? UserProfile.estimatedMaxHeartRate(forAge: age)
    }

    /// Tanaka et al. (2001): a better-validated estimate than the old 220 − age.
    static func estimatedMaxHeartRate(forAge age: Int) -> Int {
        Int((208.0 - 0.7 * Double(age)).rounded())
    }

    static let `default` = UserProfile(
        name: "Athlete",
        age: 35,
        restingHeartRate: 55,
        measuredMaxHeartRate: nil,
        restingHeartRateSource: .estimated,
        maxHeartRateSource: .estimated
    )
}
