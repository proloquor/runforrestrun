import Foundation
import Combine

/// Persists completed workouts to a JSON file in Application Support.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []

    private let fileURL: URL

    init(filename: String = "workout-history.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent(filename)
        load()
    }

    func add(_ session: WorkoutSession) {
        sessions.insert(session, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) else { return }
        sessions = decoded.sorted { $0.startedAt > $1.startedAt }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
