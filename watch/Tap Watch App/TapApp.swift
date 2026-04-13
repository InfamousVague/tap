import SwiftUI

@main
struct TapApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Mirror keychain credentials to shared UserDefaults
                    // so the widget extension can access them
                    KeychainService.shared.syncToSharedDefaults()
                }
        }
    }
}
