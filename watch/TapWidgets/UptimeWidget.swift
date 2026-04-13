import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Uptime Widget

struct UptimeIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Server Uptime"
    static var description = IntentDescription("View uptime for a specific server or all servers.")

    @Parameter(title: "Server")
    var server: ServerAppEntity?
}

struct UptimeProvider: AppIntentTimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func placeholder(in context: Context) -> UptimeEntry {
        UptimeEntry(date: .now, serverName: nil, servers: [
            UptimeServer(name: "prod", uptime: "45 days, 3:22", isUp: true),
            UptimeServer(name: "staging", uptime: "12 days, 1:05", isUp: true),
        ])
    }

    func snapshot(for configuration: UptimeIntent, in context: Context) async -> UptimeEntry {
        readEntry(for: configuration)
    }

    func timeline(for configuration: UptimeIntent, in context: Context) async -> Timeline<UptimeEntry> {
        let entry = readEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    func recommendations() -> [AppIntentRecommendation<UptimeIntent>] {
        let allIntent = UptimeIntent()
        var recs = [AppIntentRecommendation(intent: allIntent, description: "All Servers")]

        if let defaults,
           let data = defaults.data(forKey: "widget_overviews"),
           let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) {
            for o in overviews {
                let intent = UptimeIntent()
                intent.server = ServerAppEntity(id: o.serverId, name: o.serverName)
                recs.append(AppIntentRecommendation(intent: intent, description: o.serverName))
            }
        }

        return recs
    }

    private func readEntry(for config: UptimeIntent) -> UptimeEntry {
        guard let defaults,
              let data = defaults.data(forKey: "widget_overviews"),
              let overviews = try? JSONDecoder().decode([WidgetOverview].self, from: data) else {
            return UptimeEntry(date: .now, serverName: nil, servers: [])
        }

        let selectedServer = config.server
        let isAll = selectedServer == nil || selectedServer?.id == "__all__"
        let filtered = isAll ? overviews : overviews.filter { $0.serverId == selectedServer?.id }
        let serverName: String? = isAll ? nil : selectedServer?.name

        let servers = filtered.map { o in
            UptimeServer(name: o.serverName, uptime: o.uptime, isUp: o.isUp)
        }
        return UptimeEntry(date: .now, serverName: serverName, servers: servers)
    }
}

struct UptimeServer: Identifiable {
    var id: String { name }
    let name: String
    let uptime: String?
    let isUp: Bool
}

struct UptimeEntry: TimelineEntry {
    let date: Date
    let serverName: String?
    let servers: [UptimeServer]

    var shortestUptime: String? {
        servers.compactMap(\.uptime).min(by: { $0.count < $1.count })
    }
}

struct UptimeWidget: Widget {
    let kind = "UptimeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: UptimeIntent.self, provider: UptimeProvider()) { entry in
            UptimeWidgetView(entry: entry)
        }
        .configurationDisplayName("Server Uptime")
        .description("Uptime for a server or your fleet.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

struct UptimeWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: UptimeEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangularView
            case .accessoryCircular:
                circularView
            case .accessoryInline:
                inlineView
            default:
                circularView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Rectangular: uptime per server

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 9))
                Text(entry.serverName != nil ? "\(entry.serverName!) Uptime" : "Uptime")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }

            if entry.servers.isEmpty {
                Text("Open Tap to sync")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                uptimeServerList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var uptimeServerList: some View {
        ForEach(entry.servers.prefix(3).indices, id: \.self) { i in
            let server = entry.servers[i]
            HStack(spacing: 4) {
                Circle()
                    .fill(server.isUp ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
                Text(server.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                Spacer()
                if let uptime = server.uptime {
                    Text(uptime)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(server.isUp ? "--" : "down")
                        .font(.system(size: 9))
                        .foregroundStyle(server.isUp ? .secondary : Color.red)
                }
            }
        }
    }

    // MARK: - Circular: clock icon + server count

    private var circularView: some View {
        VStack(spacing: 2) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
            Text("\(entry.servers.filter(\.isUp).count)/\(entry.servers.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        Group {
            if let first = entry.servers.first, let uptime = first.uptime {
                Label("\(first.name): \(uptime)", systemImage: "clock.arrow.circlepath")
            } else {
                Label("Uptime: Open Tap", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}
