import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var monitor: HeartRateMonitor
    @EnvironmentObject private var ouraClient: OuraClient

    @State private var showConnect = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    liveCard
                    ForEach(WorkoutLibrary.all) { template in
                        NavigationLink {
                            WorkoutView(template: template)
                        } label: {
                            WorkoutCard(template: template, profile: profileStore.profile)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Run Forrest Run")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showConnect = true
                    } label: {
                        Image(systemName: "sensor.tag.radiowaves.forward")
                    }
                }
            }
            .sheet(isPresented: $showConnect) {
                ConnectView()
                    .withPreviewEnvironmentSafe(appModel)
            }
        }
    }

    private var liveCard: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Live heart rate", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                SourceStatusPill()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(monitor.currentHeartRate.map(String.init) ?? "--")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("bpm")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showConnect = true
                } label: {
                    Text(ouraClient.isConnected ? "Sources" : "Connect")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
            ZoneStrip(profile: profileStore.profile, currentBPM: monitor.currentHeartRate)
        }
        .cardStyle()
    }
}

struct WorkoutCard: View {
    let template: WorkoutTemplate
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: template.category.systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                    if template.plannedDuration > 0 {
                        Text(Format.duration(template.plannedDuration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            Text(template.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Small helper so sheets get the same environment without recreating AppModel.
extension View {
    @MainActor
    func withPreviewEnvironmentSafe(_ model: AppModel) -> some View {
        self
            .environmentObject(model)
            .environmentObject(model.profileStore)
            .environmentObject(model.historyStore)
            .environmentObject(model.ouraClient)
            .environmentObject(model.monitor)
            .environmentObject(model.coach)
    }
}

#Preview {
    HomeView().withPreviewEnvironment()
}
