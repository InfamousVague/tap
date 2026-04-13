import SwiftUI

struct ServerDetailView: View {
    let server: Server
    @EnvironmentObject var appState: AppState
    @State private var pingLatency: Int?
    @State private var isPinging = false

    var body: some View {
        List {
            // Status card with gauge
            Section {
                HStack(spacing: 16) {
                    LatencyGauge(latency: pingLatency ?? server.latencyMs)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            StatusDot(status: server.status)
                            Text(server.status.label)
                                .font(.caption)
                                .fontWeight(.medium)
                        }

                        Text("\(server.user ?? "root")@\(server.host)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(":\(server.port ?? 22)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)
            }

            // Metrics (from overview) — right under status card
            if let overview = appState.overview(for: server.id), overview.isUp {
                Section {
                    HStack(spacing: 6) {
                        if let disk = overview.disk {
                            MiniMetric(
                                icon: "internaldrive",
                                value: "\(disk.usePercent)%",
                                percent: Double(disk.usePercent) / 100.0,
                                status: overview.diskStatus
                            )
                        }
                        if let mem = overview.memory {
                            MiniMetric(
                                icon: "memorychip",
                                value: "\(mem.usePercent)%",
                                percent: Double(mem.usePercent) / 100.0,
                                status: overview.memoryStatus
                            )
                        }
                        if let load = overview.load, !load.isEmpty {
                            MiniMetric(
                                icon: "cpu",
                                value: String(format: "%.1f", load[0]),
                                percent: min(load[0] / 4.0, 1.0),
                                status: overview.loadStatus
                            )
                        }
                    }
                    .padding(.vertical, 12)
                } header: {
                    Text("Stats")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Ping button
            Section {
                Button {
                    isPinging = true
                    HapticService.shared.play(.start)
                    Task {
                        let result = await appState.pingServer(serverId: server.id)
                        withAnimation(.spring(response: 0.3)) {
                            pingLatency = result?.latencyMs
                        }
                        isPinging = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.horizontal")
                            .symbolEffect(.bounce, value: isPinging)
                        Text(isPinging ? "Pinging..." : "Ping Server")
                        Spacer()
                        if let latency = pingLatency {
                            Text("\(latency)ms")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(latencyColor(latency))
                        }
                    }
                    .font(.caption)
                }
                .tint(.amber)
                .disabled(isPinging)
            }

            // Info details (from overview)
            if let overview = appState.overview(for: server.id), overview.isUp {
                Section {
                    if let os = overview.os {
                        DetailRow(label: "OS", value: os)
                    }
                    if let kernel = overview.kernel {
                        DetailRow(label: "Kernel", value: kernel)
                    }
                    if let ip = overview.ip {
                        DetailRow(label: "IP", value: ip)
                    }
                    if let uptime = overview.uptime {
                        DetailRow(label: "Uptime", value: uptime)
                    }
                    if let disk = overview.disk {
                        DetailRow(label: "Disk", value: "\(disk.used) / \(disk.total)")
                    }
                    if let mem = overview.memory {
                        DetailRow(label: "Memory", value: "\(mem.usedMb)MB / \(mem.totalMb)MB")
                    }
                    if let load = overview.load, load.count >= 3 {
                        DetailRow(label: "Load", value: String(format: "%.2f / %.2f / %.2f", load[0], load[1], load[2]))
                    }
                    if let dr = overview.dockerRunning, let dt = overview.dockerTotal {
                        DetailRow(label: "Docker", value: "\(dr) running / \(dt) total")
                    }
                } header: {
                    Text("Info")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Server info
            Section {
                HStack {
                    Text("Commands")
                        .font(.caption)
                    Spacer()
                    Text("\(server.commands.count)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.amber)
                }
                HStack {
                    Text("Port")
                        .font(.caption)
                    Spacer()
                    Text("\(server.port ?? 22)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Pinned commands
            let pinned = server.commands.filter { $0.pinned }
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { command in
                        CommandRow(command: command, server: server)
                    }
                } header: {
                    Label("Pinned", systemImage: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.amber)
                }
            }

            // All commands
            if !server.commands.isEmpty {
                Section("Commands") {
                    ForEach(server.commands.sorted(by: { $0.sortOrder < $1.sortOrder })) { command in
                        CommandRow(command: command, server: server)
                    }
                }
            }

            // Suites
            if !server.suites.isEmpty {
                Section("Suites") {
                    ForEach(server.suites) { suite in
                        Label(suite.label, systemImage: "list.bullet.rectangle")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(server.name)
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .amber }
        return .red
    }
}

// MARK: - Latency gauge

struct LatencyGauge: View {
    let latency: Int?

    var body: some View {
        Gauge(value: gaugeValue, in: 0...1) {
            Text("ms")
                .font(.system(size: 8))
        } currentValueLabel: {
            if let latency = latency {
                Text("\(latency)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .gaugeStyle(.accessoryCircular)
        .tint(gaugeGradient)
        .frame(width: 52, height: 52)
    }

    private var gaugeValue: Double {
        guard let ms = latency else { return 0 }
        return min(Double(ms) / 200.0, 1.0)
    }

    private var gaugeGradient: Gradient {
        Gradient(colors: [.green, .amber, .red])
    }
}

// MARK: - Detail row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Command row

struct CommandRow: View {
    let command: Command
    let server: Server

    /// Icon from preset system or fallback
    private var commandIcon: String {
        // Try to match against known presets
        if let preset = CommandPreset.all.first(where: { command.command.hasPrefix($0.command.replacingOccurrences(of: "{{", with: "").components(separatedBy: " ").first ?? "NOMATCH") }) {
            return preset.icon
        }
        // Fallback based on command content
        let cmd = command.command.lowercased()
        if cmd.contains("reboot") || cmd.contains("shutdown") { return "power" }
        if cmd.contains("restart") { return "arrow.clockwise" }
        if cmd.contains("status") || cmd.contains("health") { return "stethoscope" }
        if cmd.contains("log") || cmd.contains("journal") { return "doc.text" }
        if cmd.contains("docker") { return "shippingbox" }
        if cmd.contains("git") { return "arrow.triangle.branch" }
        if cmd.contains("nginx") { return "globe" }
        if cmd.contains("redis") || cmd.contains("postgres") || cmd.contains("mysql") { return "cylinder" }
        if cmd.contains("disk") || cmd.contains("df ") { return "internaldrive" }
        if cmd.contains("memory") || cmd.contains("free ") { return "memorychip" }
        if cmd.contains("cpu") || cmd.contains("uptime") { return "cpu" }
        return command.confirm ? "exclamationmark.shield.fill" : "play.fill"
    }

    private var iconColor: Color {
        if command.confirm { return .orange }
        let cmd = command.command.lowercased()
        if cmd.contains("reboot") || cmd.contains("shutdown") || cmd.contains("stop") { return .red }
        if cmd.contains("restart") || cmd.contains("reload") { return .orange }
        return .amber
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 8) {
                Image(systemName: commandIcon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.label)
                        .font(.body)
                    Text(command.command)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var destination: some View {
        if command.confirm {
            CommandConfirmView(command: command, server: server)
        } else {
            CommandRunView(command: command, server: server)
        }
    }
}
