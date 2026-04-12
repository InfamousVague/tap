import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            // Status section
            Section {
                HStack {
                    Label("Status", systemImage: "circle.fill")
                        .foregroundStyle(server.statusColor == .up ? .green : .red)
                    Spacer()
                    Text(server.statusColor.label)
                        .foregroundStyle(.secondary)
                }

                if let latency = server.latencyMs {
                    HStack {
                        Label("Latency", systemImage: "bolt")
                        Spacer()
                        Text("\(latency)ms")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("Host", systemImage: "network")
                    Spacer()
                    Text("\(server.user)@\(server.host)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Pinned commands
            let pinned = server.commands.filter { $0.pinned }
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { command in
                        CommandRow(command: command, server: server)
                    }
                }
            }

            // All commands
            Section("Commands") {
                ForEach(server.commands) { command in
                    CommandRow(command: command, server: server)
                }
            }

            // Suites
            if !server.suites.isEmpty {
                Section("Suites") {
                    ForEach(server.suites) { suite in
                        NavigationLink(destination: Text(suite.label)) {
                            Label(suite.label, systemImage: "list.bullet.rectangle")
                        }
                    }
                }
            }
        }
        .navigationTitle(server.name)
    }
}

struct CommandRow: View {
    let command: Command
    let server: Server
    @EnvironmentObject var appState: AppState

    var body: some View {
        if command.confirm {
            NavigationLink(destination: CommandConfirmView(command: command, server: server)) {
                commandLabel
            }
        } else {
            NavigationLink(destination: CommandRunView(command: command, server: server)) {
                commandLabel
            }
        }
    }

    private var commandLabel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(command.label)
                    .font(.body)
                Text(command.command)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if command.pinned {
                Spacer()
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.amber)
            }
        }
    }
}
