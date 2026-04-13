import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Docker Status Widget

struct DockerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Docker Status"
    static var description = IntentDescription("View Docker container status for a specific server or all servers.")

    @Parameter(title: "Server")
    var server: ServerAppEntity?
}

struct DockerProvider: AppIntentTimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func placeholder(in context: Context) -> DockerEntry {
        DockerEntry(date: .now, serverName: nil, running: 8, total: 10, servers: [
            DockerServer(name: "prod", running: 5, total: 5),
            DockerServer(name: "staging", running: 3, total: 5),
        ])
    }

    func snapshot(for configuration: DockerIntent, in context: Context) async -> DockerEntry {
        readEntry(for: configuration)
    }

    func timeline(for configuration: DockerIntent, in context: Context) async -> Timeline<DockerEntry> {
        let entry = readEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<DockerIntent>] {
        let allIntent = DockerIntent()
        var recs = [AppIntentRecommendation(intent: allIntent, description: "All Servers")]

        if let defaults,
           let data = defaults.data(forKey: "widget_overviews"),
           let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) {
            for o in overviews where o.dockerRunning != nil {
                let intent = DockerIntent()
                intent.server = ServerAppEntity(id: o.serverId, name: o.serverName)
                recs.append(AppIntentRecommendation(intent: intent, description: o.serverName))
            }
        }

        return recs
    }

    private func readEntry(for config: DockerIntent) -> DockerEntry {
        guard let defaults,
              let data = defaults.data(forKey: "widget_overviews"),
              let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) else {
            return DockerEntry(date: .now, serverName: nil, running: 0, total: 0, servers: [])
        }

        let selectedServer = config.server
        let isAll = selectedServer == nil || selectedServer?.id == "__all__"
        let filtered = isAll ? overviews : overviews.filter { $0.serverId == selectedServer?.id }
        let serverName: String? = isAll ? nil : selectedServer?.name

        let dockerServers = filtered.compactMap { o -> DockerServer? in
            guard let r = o.dockerRunning, let t = o.dockerTotal else { return nil }
            return DockerServer(name: o.serverName, running: r, total: t)
        }

        let totalRunning = dockerServers.reduce(0) { $0 + $1.running }
        let totalAll = dockerServers.reduce(0) { $0 + $1.total }

        return DockerEntry(date: .now, serverName: serverName, running: totalRunning, total: totalAll, servers: dockerServers)
    }
}

struct DockerServer: Identifiable {
    var id: String { name }
    let name: String
    let running: Int
    let total: Int
    var allRunning: Bool { running == total }
}

struct DockerEntry: TimelineEntry {
    let date: Date
    let serverName: String?
    let running: Int
    let total: Int
    let servers: [DockerServer]
    var allRunning: Bool { running == total && total > 0 }
}

struct DockerWidget: Widget {
    let kind = "DockerWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: DockerIntent.self, provider: DockerProvider()) { entry in
            DockerWidgetView(entry: entry)
        }
        .configurationDisplayName("Docker Status")
        .description("Running containers for a server or your fleet.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

struct DockerWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: DockerEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circularView
            case .accessoryRectangular:
                rectangularView
            case .accessoryInline:
                inlineView
            case .accessoryCorner:
                cornerView
            default:
                circularView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Circular: container gauge

    private var circularView: some View {
        Gauge(value: Double(entry.running), in: 0...Double(max(entry.total, 1))) {
            Image(systemName: "shippingbox")
                .font(.system(size: 9))
        } currentValueLabel: {
            Text("\(entry.running)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(entry.allRunning ? Gradient(colors: [.green, .green]) : Gradient(colors: [.orange, .red]))
    }

    // MARK: - Rectangular: per-server docker status

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 9))
                Text(entry.serverName != nil ? "\(entry.serverName!) Docker" : "Docker")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(entry.running)/\(entry.total)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(entry.allRunning ? Color.green : Color.orange)
            }

            if entry.servers.isEmpty {
                Text("No Docker hosts")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                dockerServerList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var dockerServerList: some View {
        ForEach(entry.servers.prefix(3).indices, id: \.self) { i in
            let server = entry.servers[i]
            HStack(spacing: 4) {
                Circle()
                    .fill(server.allRunning ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
                Text(server.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                Spacer()
                Text("\(server.running)/\(server.total)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        Group {
            if entry.total > 0 {
                let prefix = entry.serverName ?? "Docker"
                Label("\(prefix): \(entry.running)/\(entry.total) running", systemImage: "shippingbox")
            } else {
                Label("Docker: No data", systemImage: "shippingbox")
            }
        }
    }

    // MARK: - Corner

    private var cornerView: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: 20))
            .foregroundStyle(entry.allRunning ? Color.green : Color.orange)
            .widgetLabel {
                if entry.total > 0 {
                    Text("\(entry.running)/\(entry.total) up")
                } else {
                    Text("Docker")
                }
            }
    }
}
