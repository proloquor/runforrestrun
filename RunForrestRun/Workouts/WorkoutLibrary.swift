import Foundation

/// Builders for the three built-in workouts. Kept as functions (not constants) so
/// the phase UUIDs are fresh per session.
enum WorkoutLibrary {

    static var all: [WorkoutTemplate] { [norwegian4x4(), zone2Run(), zoneTest()] }

    static func template(for category: WorkoutTemplate.Category) -> WorkoutTemplate {
        switch category {
        case .norwegian4x4: return norwegian4x4()
        case .zone2: return zone2Run()
        case .zoneTest: return zoneTest()
        }
    }

    // MARK: - Norwegian 4×4

    /// The classic Norwegian 4×4 VO₂max interval session:
    /// 10 min warm-up → 4 × (4 min hard @ 85–95% HRmax + 3 min recovery @ 60–70%)
    /// → 5 min cool-down. Alerts enforced only during the hard bouts.
    static func norwegian4x4() -> WorkoutTemplate {
        var phases: [WorkoutPhase] = [
            WorkoutPhase(
                kind: .warmup,
                title: "Warm-up",
                duration: 10 * 60,
                target: .percentMax(0.55...0.70),
                spokenCue: "Warm up for ten minutes. Easy effort.",
                enforceTarget: false
            )
        ]

        for interval in 1...4 {
            phases.append(
                WorkoutPhase(
                    kind: .work,
                    title: "Interval \(interval) · Hard",
                    duration: 4 * 60,
                    target: .percentMax(0.85...0.95),
                    spokenCue: "Interval \(interval). Four minutes. Push hard, eighty-five to ninety-five percent.",
                    enforceTarget: true
                )
            )
            if interval < 4 {
                phases.append(
                    WorkoutPhase(
                        kind: .recovery,
                        title: "Recovery \(interval)",
                        duration: 3 * 60,
                        target: .percentMax(0.60...0.70),
                        spokenCue: "Recover. Three minutes easy.",
                        enforceTarget: false
                    )
                )
            }
        }

        phases.append(
            WorkoutPhase(
                kind: .cooldown,
                title: "Cool-down",
                duration: 5 * 60,
                target: .percentMax(0.50...0.65),
                spokenCue: "Cool down. Five minutes easy. Great work.",
                enforceTarget: false
            )
        )

        return WorkoutTemplate(
            category: .norwegian4x4,
            name: "Norwegian 4×4",
            summary: "4 × 4 min @ 85–95% HRmax, 3 min recovery. ~38 min. Builds VO₂max.",
            phases: phases
        )
    }

    // MARK: - Zone 2 Run

    /// A steady aerobic-base run held in Zone 2. Default 45 minutes plus a short
    /// warm-up ramp; alerts fire whenever you drift out of Zone 2.
    static func zone2Run(mainDuration: TimeInterval = 45 * 60) -> WorkoutTemplate {
        let phases: [WorkoutPhase] = [
            WorkoutPhase(
                kind: .warmup,
                title: "Warm-up",
                duration: 5 * 60,
                target: .zone(.zone1),
                spokenCue: "Warm up for five minutes, easing into Zone two.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .steady,
                title: "Zone 2 Steady",
                duration: mainDuration,
                target: .zone(.zone2),
                spokenCue: "Zone two. Settle into an easy, conversational pace and hold it here.",
                enforceTarget: true
            ),
            WorkoutPhase(
                kind: .cooldown,
                title: "Cool-down",
                duration: 5 * 60,
                target: .zone(.zone1),
                spokenCue: "Cool down. Five minutes easy.",
                enforceTarget: false
            )
        ]

        return WorkoutTemplate(
            category: .zone2,
            name: "Zone 2 Run",
            summary: "Steady aerobic run held in Zone 2 (~60–70% HRR). Builds your aerobic base.",
            phases: phases
        )
    }

    // MARK: - HR Zone Test

    /// A guided ramp test to *measure* your true max HR (rather than estimate it).
    /// Progressive build stages, one all-out effort (open-ended — advance manually
    /// at failure), then a cool-down. The engine records the peak HR seen and
    /// offers to save it to your profile, which recalibrates every zone.
    static func zoneTest() -> WorkoutTemplate {
        let phases: [WorkoutPhase] = [
            WorkoutPhase(
                kind: .warmup,
                title: "Warm-up",
                duration: 5 * 60,
                target: .percentMax(0.50...0.65),
                spokenCue: "Let's find your true max heart rate. Warm up easy for five minutes.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .testStage,
                title: "Build 1 · Moderate",
                duration: 3 * 60,
                target: .percentMax(0.70...0.80),
                spokenCue: "Build one. Moderate effort for three minutes.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .testStage,
                title: "Build 2 · Hard",
                duration: 3 * 60,
                target: .percentMax(0.80...0.88),
                spokenCue: "Build two. Hard effort. Three minutes.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .testStage,
                title: "Build 3 · Very hard",
                duration: 2 * 60,
                target: .percentMax(0.88...0.95),
                spokenCue: "Build three. Very hard now. Two minutes.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .allOut,
                title: "All-out",
                duration: nil, // open-ended: tap Next when you can't hold on
                target: .percentMax(0.95...1.00),
                spokenCue: "All out. Empty the tank. Tap next when you cannot hold the pace.",
                enforceTarget: false
            ),
            WorkoutPhase(
                kind: .cooldown,
                title: "Cool-down",
                duration: 5 * 60,
                target: .percentMax(0.45...0.60),
                spokenCue: "Cool down easy for five minutes. We captured your peak heart rate.",
                enforceTarget: false
            )
        ]

        return WorkoutTemplate(
            category: .zoneTest,
            name: "HR Zone Test",
            summary: "Guided ramp test that measures your true max HR and recalibrates every zone.",
            phases: phases
        )
    }
}
