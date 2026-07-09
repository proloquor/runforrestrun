import SwiftUI

@main
struct RunForrestRunApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(appModel.profileStore)
                .environmentObject(appModel.historyStore)
                .environmentObject(appModel.ouraClient)
                .environmentObject(appModel.monitor)
                .environmentObject(appModel.coach)
                .environmentObject(appModel.ringLogger)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
