import SwiftUI

/// Content without NavigationStack (for embedding in TabView)
struct QuickActionsContent: View {
    @EnvironmentObject var appState: AppState

    private var pinnedCommands: [(command: Command, server: Server)] {
        appState.servers.flatMap { server in
            server.commands
                .filter { $0.pinned }
                .map { (command: $0, server: server) }
        }
    }

    private var serverHealth: (up: Int, down: Int, total: Int, warnings: Int) {
        let up = appState.servers.filter { $0.status == .up }.count
        let down = appState.servers.filter { $0.status == .down }.count
        let warnings = appState.overviews.values.filter { $0.overallHealth == .warning }.count
        return (up, down, appState.servers.count, warnings)
    }

    private var downServers: [Server] {
        appState.servers.filter { $0.status == .down }
    }

    private var warningServers: [(Server, ServerOverview)] {
        appState.servers.compactMap { server in
            guard let overview = appState.overview(for: server.id),
                  overview.overallHealth == .warning || overview.overallHealth == .critical,
                  server.status != .down else { return nil }
            return (server, overview)
        }
    }

    var body: some View {
        List {
            // Health overview with ring gauge
            Section {
                VStack(spacing: 10) {
                    // Server health ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 6)
                            .frame(width: 64, height: 64)

                        Circle()
                            .trim(from: 0, to: healthFraction)
                            .stroke(
                                healthColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 64, height: 64)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text("\(serverHealth.up)/\(serverHealth.total)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                            Text("UP")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .tracking(1)
                        }
                    }
                    .padding(.top, 4)

                    // Stats row
                    HStack(spacing: 0) {
                        StatPill(value: "\(serverHealth.up)", label: "Up", color: .green)
                        StatPill(value: "\(serverHealth.down)", label: "Down", color: serverHealth.down > 0 ? .red : .secondary)
                        StatPill(value: "\(serverHealth.warnings)", label: "Warn", color: serverHealth.warnings > 0 ? .amber : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }

            // Down server alerts
            if !downServers.isEmpty {
                Section {
                    ForEach(downServers) { server in
                        NavigationLink(destination: ServerDetailView(server: server)) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(server.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text("Unreachable")
                                        .font(.system(.caption2))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                } header: {
                    Label("Down", systemImage: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            // Warning alerts (high disk, memory, CPU)
            if !warningServers.isEmpty {
                Section {
                    ForEach(warningServers, id: \.0.id) { server, overview in
                        NavigationLink(destination: ServerDetailView(server: server)) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.amber)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(server.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    HStack(spacing: 6) {
                                        if overview.diskStatus == .warning || overview.diskStatus == .critical {
                                            Label("Disk \(overview.disk?.usePercent ?? 0)%", systemImage: "internaldrive")
                                                .font(.system(size: 8))
                                                .foregroundStyle(overview.diskStatus.color)
                                        }
                                        if overview.memoryStatus == .warning || overview.memoryStatus == .critical {
                                            Label("Mem \(overview.memory?.usePercent ?? 0)%", systemImage: "memorychip")
                                                .font(.system(size: 8))
                                                .foregroundStyle(overview.memoryStatus.color)
                                        }
                                        if overview.loadStatus == .warning || overview.loadStatus == .critical {
                                            let loadVal = overview.load?.first ?? 0
                                            Label(String(format: "CPU %.1f", loadVal), systemImage: "cpu")
                                                .font(.system(size: 8))
                                                .foregroundStyle(overview.loadStatus.color)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.amber)
                }
            }

            // Pinned commands / Quick actions
            if !pinnedCommands.isEmpty {
                Section {
                    ForEach(pinnedCommands, id: \.command.id) { item in
                        NavigationLink(destination: destination(for: item)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.command.label)
                                        .font(.body)
                                    Text(item.server.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if item.command.confirm {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }

                                StatusDot(status: item.server.status)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Label("Quick Actions", systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.amber)
                }
            }

            // Fleet summary
            if !appState.servers.isEmpty {
                Section {
                    ForEach(appState.servers) { server in
                        let overview = appState.overview(for: server.id)
                        NavigationLink(destination: ServerDetailView(server: server)) {
                            HStack(spacing: 8) {
                                StatusDot(status: server.status)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(server.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    if let overview, overview.isUp {
                                        HStack(spacing: 4) {
                                            if let disk = overview.disk {
                                                Text("D:\(disk.usePercent)%")
                                                    .foregroundStyle(overview.diskStatus.color)
                                            }
                                            if let mem = overview.memory {
                                                Text("M:\(mem.usePercent)%")
                                                    .foregroundStyle(overview.memoryStatus.color)
                                            }
                                        }
                                        .font(.system(size: 8, design: .monospaced))
                                    } else if let latency = server.latencyMs {
                                        Text("\(latency)ms")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(latencyColor(latency))
                                    }
                                }
                                Spacer()
                                if let overview {
                                    Image(systemName: overview.overallHealth.icon)
                                        .font(.system(size: 9))
                                        .foregroundStyle(overview.overallHealth.color)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Fleet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Overview")
    }

    private var healthFraction: CGFloat {
        guard serverHealth.total > 0 else { return 0 }
        return CGFloat(serverHealth.up) / CGFloat(serverHealth.total)
    }

    private var healthColor: Color {
        if serverHealth.down > 0 { return .red }
        if serverHealth.warnings > 0 { return .amber }
        return .green
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .amber }
        return .red
    }

    @ViewBuilder
    private func destination(for item: (command: Command, server: Server)) -> some View {
        if item.command.confirm {
            CommandConfirmView(command: item.command, server: item.server)
        } else {
            CommandRunView(command: item.command, server: item.server)
        }
    }
}

// MARK: - Stat pill for overview

struct StatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Standalone version with its own NavigationStack
struct QuickActionsView: View {
    var body: some View {
        NavigationStack {
            QuickActionsContent()
        }
    }
}
