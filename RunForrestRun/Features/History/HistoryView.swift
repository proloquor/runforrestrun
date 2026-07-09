import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.sessions.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("History")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.headline)
            Text("Finished sessions show up here with your time in zone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var list: some View {
        List {
            ForEach(historyStore.sessions) { session in
                HistoryRow(session: session)
                    .listRowBackground(Theme.card)
            }
            .onDelete { historyStore.delete(at: $0) }
        }
        .scrollContentBackground(.hidden)
    }
}

struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: session.category.systemImage)
                    .foregroundStyle(Theme.accent)
                Text(session.templateName).font(.headline)
                Spacer()
                Text(Format.mediumDate.string(from: session.startedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                metric("Time", Format.clock(session.duration))
                if let avg = session.averageHeartRate { metric("Avg", "\(avg)") }
                if let peak = session.peakHeartRate { metric("Peak", "\(peak)") }
                if session.category != .zoneTest {
                    metric("In zone", "\(Int(session.timeInZoneFraction * 100))%")
                }
                if let max = session.measuredMaxHeartRate {
                    metric("Max HR", "\(max)")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.subheadline.bold().monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HistoryView().withPreviewEnvironment()
}
