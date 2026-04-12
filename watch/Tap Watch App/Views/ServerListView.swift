import SwiftUI

struct ServerListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                if appState.servers.isEmpty && !appState.isLoading {
                    ContentUnavailableView {
                        Label("No Servers", systemImage: "server.rack")
                    } description: {
                        Text("Add servers via the companion app or relay.")
                    }
                }

                ForEach(appState.servers) { server in
                    NavigationLink(destination: ServerDetailView(server: server)) {
                        ServerRow(server: server)
                    }
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appState.refreshConfig() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                await appState.refreshConfig()
            }
            .overlay {
                if appState.isLoading && appState.servers.isEmpty {
                    ProgressView()
                }
            }
        }
    }
}

struct ServerRow: View {
    let server: Server

    var body: some View {
        HStack(spacing: 10) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(server.host)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let latency = server.latencyMs {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text("\(latency)ms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("\(server.commands.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
    }

    private var statusColor: Color {
        switch server.statusColor {
        case .up: return .green
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
