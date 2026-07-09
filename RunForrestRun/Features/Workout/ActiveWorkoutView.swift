import SwiftUI

struct ActiveWorkoutView: View {
    @ObservedObject var engine: WorkoutEngine
    /// Called to tear down the full-screen cover (clears the presenting binding).
    var onClose: () -> Void = {}

    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var coach: AudioCoach

    @State private var didStart = false
    @State private var showEndConfirm = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let session = engine.finishedSession {
                WorkoutSummaryView(session: session, onDone: onClose)
            } else {
                activeContent
            }
        }
        .onAppear {
            if !didStart {
                didStart = true
                engine.start()
            }
        }
    }

    private var activeContent: some View {
        VStack(spacing: 18) {
            topBar
            phaseHeader
            HeartRateGauge(
                bpm: engine.currentHeartRate,
                fractionOfMax: engine.fractionOfMax,
                status: engine.zoneStatus,
                targetRange: engine.currentTargetRange
            )
            ZoneStatusBanner(status: engine.zoneStatus, enforced: engine.currentPhase.enforceTarget)
                .padding(.horizontal)
            ZoneStrip(profile: profileStore.profile, currentBPM: engine.currentHeartRate)
                .padding(.horizontal)
            Spacer()
            controls
        }
        .padding(.vertical, 12)
    }

    private var topBar: some View {
        HStack {
            Button {
                coach.isMuted.toggle()
            } label: {
                Image(systemName: coach.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            Spacer()
            VStack(spacing: 0) {
                Text("TOTAL").font(.caption2).foregroundStyle(.secondary)
                Text(Format.clock(engine.totalElapsed))
                    .font(.headline.monospacedDigit())
            }
            Spacer()
            Button(role: .destructive) {
                showEndConfirm = true
            } label: {
                Image(systemName: "stop.fill")
            }
        }
        .padding(.horizontal)
        .confirmationDialog("End this workout?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { engine.end() }
            Button("Keep going", role: .cancel) {}
        }
    }

    private var phaseHeader: some View {
        VStack(spacing: 6) {
            Text("PHASE \(engine.currentPhaseIndex + 1) OF \(engine.template.phases.count)")
                .font(.caption).foregroundStyle(.secondary)
            Text(engine.currentPhase.title)
                .font(.title2.bold())
            if let remaining = engine.phaseRemaining {
                Text(Format.clock(remaining))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                ProgressView(value: engine.phaseProgress)
                    .tint(Theme.accent)
                    .padding(.horizontal, 40)
            } else {
                Text("Open-ended — tap Next when done")
                    .font(.subheadline)
                    .foregroundStyle(Theme.warning)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                engine.state == .running ? engine.pause() : engine.resume()
            } label: {
                Label(engine.state == .running ? "Pause" : "Resume",
                      systemImage: engine.state == .running ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)

            Button {
                engine.advancePhase()
            } label: {
                Label(engine.isLastPhase ? "Finish" : "Next", systemImage: "forward.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }
}

/// Post-workout summary. For the zone test it offers to save the measured max HR.
struct WorkoutSummaryView: View {
    let session: WorkoutSession
    var onDone: () -> Void

    @EnvironmentObject private var profileStore: ProfileStore
    @State private var savedMax = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.good)
                    .padding(.top, 40)
                Text("Workout complete")
                    .font(.title.bold())
                Text(session.templateName)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    metric("Time", Format.clock(session.duration))
                    metric("Avg HR", session.averageHeartRate.map { "\($0)" } ?? "–")
                    metric("Peak HR", session.peakHeartRate.map { "\($0)" } ?? "–")
                }

                if session.category != .zoneTest {
                    VStack(spacing: 6) {
                        Text("\(Int(session.timeInZoneFraction * 100))%")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Text("time in target zone")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle()
                }

                if session.category == .zoneTest, let max = session.measuredMaxHeartRate {
                    zoneTestResult(max: max)
                }

                Button {
                    onDone()
                } label: {
                    Text("Done").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(16)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold().monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func zoneTestResult(max: Int) -> some View {
        VStack(spacing: 12) {
            Text("Measured max heart rate")
                .font(.headline)
            Text("\(max) bpm")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.danger)
            if savedMax {
                Label("Saved — your zones are recalibrated", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.good)
            } else {
                Button {
                    profileStore.updateMaxHeartRate(max, source: .measured)
                    savedMax = true
                } label: {
                    Text("Save to profile & recalibrate zones")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }
}

#Preview("Summary") {
    WorkoutSummaryView(
        session: WorkoutSession(
            templateName: "Norwegian 4×4", category: .norwegian4x4, startedAt: Date(),
            duration: 2280, averageHeartRate: 158, peakHeartRate: 181,
            timeInZoneFraction: 0.82, measuredMaxHeartRate: nil, samples: []
        ),
        onDone: {}
    )
    .withPreviewEnvironment()
}
