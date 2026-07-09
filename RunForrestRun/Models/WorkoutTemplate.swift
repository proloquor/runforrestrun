import Foundation

/// One segment of a workout. `duration == nil` means "open ended" (user taps to
/// advance) — used by the zone test's all-out stage where you go until failure.
struct WorkoutPhase: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case warmup
        case work
        case recovery
        case steady
        case cooldown
        case testStage
        case allOut
    }

    let id: UUID
    var kind: Kind
    var title: String
    var duration: TimeInterval?
    var target: HeartRateTarget?
    /// Spoken when the phase begins.
    var spokenCue: String
    /// If true, out-of-zone alerts are suppressed (warmups/cooldowns/recovery).
    var enforceTarget: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        duration: TimeInterval?,
        target: HeartRateTarget?,
        spokenCue: String,
        enforceTarget: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.duration = duration
        self.target = target
        self.spokenCue = spokenCue
        self.enforceTarget = enforceTarget
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable {
    enum Category: String, Codable {
        case norwegian4x4
        case zone2
        case zoneTest

        var displayName: String {
            switch self {
            case .norwegian4x4: return "Norwegian 4×4"
            case .zone2: return "Zone 2 Run"
            case .zoneTest: return "HR Zone Test"
            }
        }

        var systemImage: String {
            switch self {
            case .norwegian4x4: return "bolt.heart.fill"
            case .zone2: return "figure.run"
            case .zoneTest: return "waveform.path.ecg"
            }
        }
    }

    let id: UUID
    var category: Category
    var name: String
    var summary: String
    var phases: [WorkoutPhase]

    init(id: UUID = UUID(), category: Category, name: String, summary: String, phases: [WorkoutPhase]) {
        self.id = id
        self.category = category
        self.name = name
        self.summary = summary
        self.phases = phases
    }

    /// Total planned duration ignoring open-ended phases.
    var plannedDuration: TimeInterval {
        phases.compactMap { $0.duration }.reduce(0, +)
    }
}
