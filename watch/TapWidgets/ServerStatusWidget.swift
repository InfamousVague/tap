import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct ServerStatusProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func placeholder(in context: Context) -> ServerStatusEntry {
        ServerStatusEntry(date: .now, totalServers: 3, upServers: 3, downServers: 0, serverNames: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ServerStatusEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ServerStatusEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    /// Read cached server status from shared UserDefaults (written by main app)
    private func readEntry() -> ServerStatusEntry {
        guard let defaults else {
            return ServerStatusEntry(date: .now, totalServers: 0, upServers: 0, downServers: 0, serverNames: [])
        }

        let total = defaults.integer(forKey: "widget_total_servers")
        let up = defaults.integer(forKey: "widget_up_servers")
        let down = defaults.integer(forKey: "widget_down_servers")
        let names = defaults.stringArray(forKey: "widget_down_names") ?? []

        return ServerStatusEntry(date: .now, totalServers: total, upServers: up, downServers: down, serverNames: names)
    }
}

// MARK: - Entry

struct ServerStatusEntry: TimelineEntry {
    let date: Date
    let totalServers: Int
    let upServers: Int
    let downServers: Int
    let serverNames: [String]
}

// MARK: - Widget

struct ServerStatusWidget: Widget {
    let kind = "ServerStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ServerStatusProvider()) { entry in
            ServerStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Server Status")
        .description("Shows your server health at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

// MARK: - Views

struct ServerStatusWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ServerStatusEntry

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

    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            if entry.totalServers > 0 {
                Gauge(value: Double(entry.upServers), in: 0...Double(max(entry.totalServers, 1))) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 10))
                } currentValueLabel: {
                    Text("\(entry.upServers)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(entry.downServers > 0 ?
                      Gradient(colors: [.green, .red]) :
                      Gradient(colors: [.green, .green])
                )
            } else {
                VStack(spacing: 2) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 14))
                    Text("--")
                        .font(.system(.caption2, design: .monospaced))
                }
            }
        }
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 11))
                Text("Tap Servers")
                    .font(.system(size: 12, weight: .semibold))
            }

            if entry.totalServers > 0 {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("\(entry.upServers) up")
                            .font(.system(size: 11, design: .monospaced))
                    }

                    if entry.downServers > 0 {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.red)
                                .frame(width: 6, height: 6)
                            Text("\(entry.downServers) down")
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                }

                if !entry.serverNames.isEmpty {
                    Text(entry.serverNames.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("Open Tap to sync")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Inline

    private var inlineView: some View {
        Group {
            if entry.totalServers > 0 {
                if entry.downServers > 0 {
                    Label("\(entry.upServers)/\(entry.totalServers) up · \(entry.downServers) down", systemImage: "exclamationmark.triangle")
                } else {
                    Label("\(entry.totalServers) servers all up", systemImage: "checkmark.circle")
                }
            } else {
                Label("Tap: Open app to sync", systemImage: "server.rack")
            }
        }
    }

    // MARK: - Corner

    private var cornerView: some View {
        Image(systemName: entry.downServers > 0 ? "exclamationmark.triangle.fill" : "server.rack")
            .font(.system(size: 20))
            .foregroundStyle(entry.downServers > 0 ? .red : .green)
            .widgetLabel {
                if entry.totalServers > 0 {
                    Text("\(entry.upServers)/\(entry.totalServers) up")
                } else {
                    Text("Tap")
                }
            }
    }
}

// MARK: - Previews

#Preview(as: .accessoryCircular) {
    ServerStatusWidget()
} timeline: {
    ServerStatusEntry(date: .now, totalServers: 5, upServers: 5, downServers: 0, serverNames: [])
    ServerStatusEntry(date: .now, totalServers: 5, upServers: 3, downServers: 2, serverNames: ["staging", "monitoring"])
}
