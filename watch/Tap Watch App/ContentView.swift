import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if appState.isConfigured {
            MainTabView()
                .environmentObject(appState)
                .task {
                    await appState.refreshConfig()
                    await appState.refreshOverview()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            await appState.refreshConfig()
                            await appState.refreshOverview()
                        }
                    }
                }
        } else {
            SetupView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ServerListContent()
                    .tag(0)
                SettingsView()
                    .tag(1)
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(.amber.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.amber)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap")
                            .font(.headline)
                        Text("v1.0")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                HStack {
                    Text("Relay")
                        .font(.body)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green.opacity(0.5), radius: 3)
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Servers")
                        .font(.body)
                    Spacer()
                    Text("\(appState.servers.count)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.amber)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button(role: .destructive) {
                    appState.disconnect()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await appState.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure? This will permanently delete your account and all data.")
        }
    }
}
