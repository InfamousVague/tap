import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                SignInView()
            }
        }
        .background(Color.stashBgPrimary)
        .task {
            await appState.checkAuth()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && appState.isAuthenticated {
                Task { await appState.loadConfig() }
            }
        }
    }
}
