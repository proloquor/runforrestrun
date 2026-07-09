import SwiftUI

/// Pre-start screen: shows the plan, target zones per phase, and a big Start button.
struct WorkoutView: View {
    let template: WorkoutTemplate

    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var monitor: HeartRateMonitor

    @State private var activeEngine: WorkoutEngine?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if template.category == .norwegian4x4 && monitor.sourceKind == .oura {
                    stripWarning
                }
                phaseList
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            startButton
        }
        .fullScreenCover(item: $activeEngine) { engine in
            ActiveWorkoutView(engine: engine) { activeEngine = nil }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: template.category.systemImage)
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                Spacer()
                SourceStatusPill()
            }
            Text(template.summary)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                stat("Duration", template.plannedDuration > 0 ? Format.duration(template.plannedDuration) : "Open")
                stat("Phases", "\(template.phases.count)")
                stat("Max HR", "\(profileStore.profile.maxHeartRate)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var stripWarning: some View {
        Label {
            Text("You're using Oura as the live source. For sharp 4×4 alerts, switch to a Bluetooth strap in Connect.")
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var phaseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The plan")
                .font(.headline)
            ForEach(Array(template.phases.enumerated()), id: \.element.id) { index, phase in
                PhaseRow(index: index, phase: phase, profile: profileStore.profile)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var startButton: some View {
        Button {
            let engine = appModel.makeEngine(for: template)
            activeEngine = engine
        } label: {
            Label("Start workout", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

struct PhaseRow: View {
    let index: Int
    let phase: WorkoutPhase
    let profile: UserProfile

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption).bold()
                .frame(width: 24, height: 24)
                .background(dotColor.opacity(0.2), in: Circle())
                .foregroundStyle(dotColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.title).font(.subheadline).bold()
                if let target = phase.target {
                    let range = target.bpmRange(for: profile)
                    Text("\(target.shortDescription) · \(range.lowerBound)–\(range.upperBound) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(phase.duration.map { Format.clock($0) } ?? "Open")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if phase.enforceTarget {
                Image(systemName: "bell.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var dotColor: Color {
        switch phase.kind {
        case .work, .allOut: return Theme.danger
        case .recovery, .cooldown, .warmup: return Theme.accent
        case .steady, .testStage: return Theme.warning
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutView(template: WorkoutLibrary.norwegian4x4())
    }
    .withPreviewEnvironment()
}
