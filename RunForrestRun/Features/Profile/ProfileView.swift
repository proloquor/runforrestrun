import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var ouraClient: OuraClient
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationStack {
            Form {
                athleteSection
                metricsSection
                zonesSection
                ouraSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private var athleteSection: some View {
        Section("Athlete") {
            TextField("Name", text: $profileStore.profile.name)
            Stepper(value: $profileStore.profile.age, in: 10...100) {
                HStack { Text("Age"); Spacer(); Text("\(profileStore.profile.age)").foregroundStyle(.secondary) }
            }
        }
    }

    private var metricsSection: some View {
        Section {
            Stepper(value: $profileStore.profile.restingHeartRate, in: 30...100) {
                HStack {
                    Text("Resting HR")
                    Spacer()
                    Text("\(profileStore.profile.restingHeartRate) bpm").foregroundStyle(.secondary)
                }
            }
            .onChange(of: profileStore.profile.restingHeartRate) { _, _ in
                profileStore.profile.restingHeartRateSource = .manual
            }

            HStack {
                Text("Max HR")
                Spacer()
                Text("\(profileStore.profile.maxHeartRate) bpm").foregroundStyle(.secondary)
                Text(maxSourceLabel).font(.caption2).foregroundStyle(.tertiary)
            }
            if profileStore.profile.measuredMaxHeartRate != nil {
                Button("Reset max HR to age estimate", role: .destructive) {
                    profileStore.profile.measuredMaxHeartRate = nil
                    profileStore.profile.maxHeartRateSource = .estimated
                }
            }
        } header: {
            Text("Heart rate")
        } footer: {
            Text("Run the HR Zone Test to measure your true max HR — it's far more accurate than the age estimate and recalibrates every zone below.")
        }
    }

    private var zonesSection: some View {
        Section("Your zones") {
            ForEach(ZoneCalculator.allZoneRanges(profile: profileStore.profile), id: \.zone) { item in
                HStack {
                    Circle().fill(item.zone.color).frame(width: 12, height: 12)
                    VStack(alignment: .leading) {
                        Text("\(item.zone.name) · \(item.zone.label)")
                        Text("\(Int(item.zone.hrrRange.lowerBound * 100))–\(Int(item.zone.hrrRange.upperBound * 100))% HRR")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.range.lowerBound)–\(item.range.upperBound)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ouraSection: some View {
        Section("Oura") {
            HStack {
                Text("Account")
                Spacer()
                Text(ouraClient.isConnected ? "Connected" : "Not connected")
                    .foregroundStyle(ouraClient.isConnected ? Theme.good : .secondary)
            }
            if ouraClient.isConnected {
                Button("Sync resting HR & age from Oura") {
                    Task { await appModel.syncProfileFromOura() }
                }
            }
        }
    }

    private var maxSourceLabel: String {
        switch profileStore.profile.maxHeartRateSource {
        case .measured: return "measured"
        case .manual: return "manual"
        case .oura: return "oura"
        case .estimated: return "estimated"
        }
    }
}

#Preview {
    ProfileView().withPreviewEnvironment()
}
