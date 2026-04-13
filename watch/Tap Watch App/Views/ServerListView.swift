import SwiftUI

/// Standalone version with its own NavigationStack (for non-tab use)
struct ServerListView: View {
    var body: some View {
        NavigationStack {
            ServerListContent()
        }
    }
}

/// Content without NavigationStack (for embedding in TabView)
struct ServerListContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            if appState.servers.isEmpty && !appState.isLoading {
                ContentUnavailableView {
                    Label("No Servers", systemImage: "server.rack")
                } description: {
                    Text("Add servers via the companion app.")
                }
            }

            ForEach(appState.servers) { server in
                NavigationLink(destination: ServerDetailView(server: server)) {
                    ServerCard(server: server, overview: appState.overview(for: server.id))
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await appState.refreshConfig()
                        await appState.refreshOverview()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .symbolEffect(.pulse, value: appState.isLoading || appState.isLoadingOverview)
                }
            }
        }
        .overlay {
            if appState.isLoading && appState.servers.isEmpty {
                ProgressView()
                    .tint(.amber)
            }
        }
    }
}

// MARK: - Server Card (rich metrics view)

struct ServerCard: View {
    let server: Server
    let overview: ServerOverview?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: status + name + health badge
            HStack(spacing: 8) {
                StatusDot(status: server.status)

                VStack(alignment: .leading, spacing: 1) {
                    Text(server.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let os = overview?.os {
                        Text(os)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(truncatedHost)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let overview {
                    Image(systemName: overview.overallHealth.icon)
                        .font(.caption)
                        .foregroundStyle(overview.overallHealth.color)
                }
            }

            if let overview, overview.isUp {
                // Metrics bar: disk / mem / cpu mini gauges
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

                // Info rows
                if let uptime = overview.uptime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                        Text(uptime)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    if let latency = overview.latencyMs ?? server.latencyMs {
                        HStack(spacing: 2) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 7))
                            Text("\(latency)ms")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(latencyColor(latency))
                    }

                    Spacer()

                    if let dr = overview.dockerRunning, let dt = overview.dockerTotal {
                        HStack(spacing: 2) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 8))
                            Text("\(dr)/\(dt)")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(dr == dt ? .green : .orange)
                    }
                }
            } else if server.status == .down {
                // Down state
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text("Server unreachable")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } else if overview == nil {
                // Loading state
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Loading metrics…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var truncatedHost: String {
        let host = server.host
        if host.count > 20 {
            return String(host.prefix(18)) + "\u{2026}"
        }
        return host
    }

    private func latencyColor(_ ms: Int) -> Color {
        if ms < 50 { return .green }
        if ms < 150 { return .amber }
        return .red
    }
}

// MARK: - Mini Metric (compact gauge for card)

struct MiniMetric: View {
    let icon: String
    let value: String
    let percent: Double
    let status: HealthLevel

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(status.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(status.color)
            }

            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(status.color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Animated status dot

struct StatusDot: View {
    let status: ServerStatus
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Pulse ring for down servers
            if status == .down {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 14, height: 14)
                    .scaleEffect(isPulsing ? 1.4 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            }

            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: status == .up ? 3 : 0)
        }
        .onAppear {
            if status == .down {
                isPulsing = true
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .up: return .green
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
