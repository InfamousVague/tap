import SwiftUI

/// Quick Actions — shown when Action Button is pressed on Ultra
/// Shows pinned commands across all servers for fast access
struct QuickActionsView: View {
    @EnvironmentObject var appState: AppState

    var pinnedCommands: [(server: Server, command: Command)] {
        appState.servers.flatMap { server in
            server.commands.filter { $0.pinned }.map { (server: server, command: $0) }
        }
    }

    var recentCommands: [(server: Server, command: Command)] {
        // TODO: Track recently used commands via SwiftData
        // For now, show first command of each server
        appState.servers.compactMap { server in
            server.commands.first.map { (server: server, command: $0) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !pinnedCommands.isEmpty {
                    Section("Pinned") {
                        ForEach(pinnedCommands, id: \.command.id) { item in
                            quickActionRow(server: item.server, command: item.command)
                        }
                    }
                }

                if !recentCommands.isEmpty {
                    Section("Recent") {
                        ForEach(recentCommands, id: \.command.id) { item in
                            quickActionRow(server: item.server, command: item.command)
                        }
                    }
                }

                if pinnedCommands.isEmpty && recentCommands.isEmpty {
                    ContentUnavailableView {
                        Label("No Quick Actions", systemImage: "bolt.slash")
                    } description: {
                        Text("Pin commands to see them here.")
                    }
                }
            }
            .navigationTitle("Quick Actions")
        }
    }

    private func quickActionRow(server: Server, command: Command) -> some View {
        NavigationLink {
            if command.confirm {
                CommandConfirmView(command: command, server: server)
            } else {
                CommandRunView(command: command, server: server)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.label)
                    .font(.body)
                Text(server.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
