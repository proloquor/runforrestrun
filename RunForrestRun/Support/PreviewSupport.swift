import SwiftUI

/// Injects the full environment from a single `AppModel` so SwiftUI previews
/// don't crash on missing `@EnvironmentObject`s.
extension View {
    @MainActor
    func withPreviewEnvironment(_ model: AppModel = AppModel()) -> some View {
        self
            .environmentObject(model)
            .environmentObject(model.profileStore)
            .environmentObject(model.historyStore)
            .environmentObject(model.ouraClient)
            .environmentObject(model.monitor)
            .environmentObject(model.coach)
            .environmentObject(model.ringLogger)
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
    }
}
