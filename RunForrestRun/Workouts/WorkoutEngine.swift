import Foundation
import Combine

/// Drives an active workout: advances through phases on a 1 Hz clock, records
/// heart-rate samples, compares live HR to the current phase's target band, and
/// asks the `AudioCoach` to fire "too high / too low / back in zone" cues with a
/// grace period so brief blips don't nag you.
@MainActor
final class WorkoutEngine: ObservableObject, Identifiable {

    let id = UUID()

    enum State: Equatable { case idle, running, paused, finished }

    enum ZoneStatus: Equatable {
        case noSignal
        case below
        case inZone
        case above

        var isOutOfZone: Bool { self == .below || self == .above }
    }

    // Published UI state
    @Published private(set) var state: State = .idle
    @Published private(set) var template: WorkoutTemplate
    @Published private(set) var currentPhaseIndex: Int = 0
    @Published private(set) var phaseElapsed: TimeInterval = 0
    @Published private(set) var totalElapsed: TimeInterval = 0
    @Published private(set) var zoneStatus: ZoneStatus = .noSignal
    @Published private(set) var currentHeartRate: Int?
    @Published private(set) var peakHeartRate: Int = 0
    /// Set once the workout ends; the UI observes this to show the summary.
    @Published private(set) var finishedSession: WorkoutSession?

    // Tuning
    private let outOfZoneGrace: TimeInterval = 5      // sustained seconds before first alert
    private let reAlertInterval: TimeInterval = 20    // repeat cadence while still out

    // Dependencies
    private let profile: UserProfile
    private let monitor: HeartRateMonitor
    private let coach: AudioCoach
    private let historyStore: HistoryStore
    private let onFinish: (WorkoutSession) -> Void

    // Internals
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var startDate = Date()
    private var recordedSamples: [HeartRateSample] = []
    private var hrSum = 0
    private var hrCount = 0
    private var enforcedSeconds = 0
    private var inZoneSeconds = 0
    private var outOfZoneDuration: TimeInterval = 0
    private var timeSinceLastAlert: TimeInterval = 0
    /// Previous tick's status, used only for alert edge-detection (distinct from
    /// the published `zoneStatus` which drives the UI).
    private var previousStatus: ZoneStatus = .noSignal

    init(
        template: WorkoutTemplate,
        profile: UserProfile,
        monitor: HeartRateMonitor,
        coach: AudioCoach,
        historyStore: HistoryStore,
        onFinish: @escaping (WorkoutSession) -> Void = { _ in }
    ) {
        self.template = template
        self.profile = profile
        self.monitor = monitor
        self.coach = coach
        self.historyStore = historyStore
        self.onFinish = onFinish
    }

    // MARK: - Derived state

    var currentPhase: WorkoutPhase { template.phases[currentPhaseIndex] }

    var currentTargetRange: ClosedRange<Int>? {
        currentPhase.target?.bpmRange(for: profile)
    }

    var phaseRemaining: TimeInterval? {
        guard let duration = currentPhase.duration else { return nil }
        return max(0, duration - phaseElapsed)
    }

    var phaseProgress: Double {
        guard let duration = currentPhase.duration, duration > 0 else { return 0 }
        return min(1, phaseElapsed / duration)
    }

    var isLastPhase: Bool { currentPhaseIndex >= template.phases.count - 1 }

    /// Where the current HR sits relative to max, for the gauge (0...1+).
    var fractionOfMax: Double {
        guard let hr = currentHeartRate else { return 0 }
        return ZoneCalculator.fractionOfMax(bpm: hr, profile: profile)
    }

    // MARK: - Lifecycle

    func start() {
        guard state == .idle else { return }
        startDate = Date()
        state = .running
        coach.activateSession()
        monitor.start()

        monitor.$currentHeartRate
            .receive(on: RunLoop.main)
            .sink { [weak self] hr in self?.currentHeartRate = hr }
            .store(in: &cancellables)

        announceCurrentPhase()
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        coach.speak("Paused.")
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
        coach.speak("Resuming.")
    }

    /// Manually advance — used by the zone test's open-ended all-out stage, or to
    /// skip a phase early.
    func advancePhase() {
        guard state == .running || state == .paused else { return }
        goToNextPhaseOrFinish()
    }

    func end() {
        finish(aborted: true)
    }

    // MARK: - Clock

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            // The timer fires on the main run loop, so we're already on the main actor.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard state == .running else { return }
        phaseElapsed += 1
        totalElapsed += 1

        recordSampleAndEvaluate()

        if let remaining = phaseRemaining, remaining <= 0 {
            goToNextPhaseOrFinish()
        }
    }

    // MARK: - HR evaluation

    private func recordSampleAndEvaluate() {
        guard let hr = currentHeartRate else {
            zoneStatus = .noSignal
            previousStatus = .noSignal
            return
        }

        recordedSamples.append(HeartRateSample(bpm: hr, timestamp: Date(), origin: monitorOrigin()))
        hrSum += hr
        hrCount += 1
        peakHeartRate = max(peakHeartRate, hr)

        let status: ZoneStatus
        if let range = currentTargetRange {
            if hr < range.lowerBound { status = .below }
            else if hr > range.upperBound { status = .above }
            else { status = .inZone }
        } else {
            status = .inZone
        }

        if currentPhase.enforceTarget {
            enforcedSeconds += 1
            if status == .inZone { inZoneSeconds += 1 }
            evaluateAlerts(for: status)
        }

        zoneStatus = status
        previousStatus = status
    }

    private func evaluateAlerts(for status: ZoneStatus) {
        if status.isOutOfZone {
            // Reset the out-of-zone clock if the direction flipped (below → above).
            if previousStatus.isOutOfZone, previousStatus != status {
                outOfZoneDuration = 0
                timeSinceLastAlert = reAlertInterval
            }
            outOfZoneDuration += 1
            timeSinceLastAlert += 1

            if outOfZoneDuration >= outOfZoneGrace, timeSinceLastAlert >= reAlertInterval {
                coach.play(status == .above ? .above : .below)
                timeSinceLastAlert = 0
            }
        } else {
            // Returned to the zone after having been out long enough to be alerted.
            if previousStatus.isOutOfZone, outOfZoneDuration >= outOfZoneGrace {
                coach.play(.backInZone)
            }
            outOfZoneDuration = 0
            timeSinceLastAlert = reAlertInterval
        }
    }

    private func monitorOrigin() -> HeartRateSample.Origin {
        switch monitor.sourceKind {
        case .bluetooth: return .ble
        case .oura: return .oura
        case .simulated: return .simulated
        }
    }

    // MARK: - Phase transitions

    private func goToNextPhaseOrFinish() {
        if isLastPhase {
            finish(aborted: false)
        } else {
            currentPhaseIndex += 1
            phaseElapsed = 0
            outOfZoneDuration = 0
            timeSinceLastAlert = reAlertInterval
            previousStatus = .noSignal
            announceCurrentPhase()
        }
    }

    private func announceCurrentPhase() {
        coach.play(.phase(currentPhase.spokenCue))
    }

    // MARK: - Finish

    private func finish(aborted: Bool) {
        guard state != .finished else { return }
        timer?.invalidate()
        timer = nil
        state = .finished
        cancellables.removeAll()

        let avg = hrCount > 0 ? Int(Double(hrSum) / Double(hrCount)) : nil
        let inZoneFraction = enforcedSeconds > 0 ? Double(inZoneSeconds) / Double(enforcedSeconds) : 0
        let measuredMax = template.category == .zoneTest ? (peakHeartRate > 0 ? peakHeartRate : nil) : nil

        let session = WorkoutSession(
            templateName: template.name,
            category: template.category,
            startedAt: startDate,
            duration: totalElapsed,
            averageHeartRate: avg,
            peakHeartRate: peakHeartRate > 0 ? peakHeartRate : nil,
            timeInZoneFraction: inZoneFraction,
            measuredMaxHeartRate: measuredMax,
            samples: recordedSamples
        )

        historyStore.add(session)
        finishedSession = session
        coach.play(.phase(aborted ? "Workout ended." : "Workout complete. Nice session."))
        coach.deactivateSession()
        onFinish(session)
    }
}
