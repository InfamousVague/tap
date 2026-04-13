import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct QuickCommandProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp")

    func placeholder(in context: Context) -> QuickCommandEntry {
        QuickCommandEntry(date: .now, pinnedCommands: [
            PinnedCommandInfo(label: "Restart API", serverName: "prod-api"),
            PinnedCommandInfo(label: "Check Disk", serverName: "prod-db"),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCommandEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCommandEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func readEntry() -> QuickCommandEntry {
        guard let defaults,
              let data = defaults.data(forKey: "widget_pinned_commands"),
              let commands = try? JSONDecoder().decode([PinnedCommandInfo].self, from: data) else {
            return QuickCommandEntry(date: .now, pinnedCommands: [])
        }
        return QuickCommandEntry(date: .now, pinnedCommands: commands)
    }
}

// MARK: - Data types

struct PinnedCommandInfo: Codable, Identifiable {
    var id: String { "\(serverName)_\(label)" }
    let label: String
    let serverName: String
}

struct QuickCommandEntry: TimelineEntry {
    let date: Date
    let pinnedCommands: [PinnedCommandInfo]
}

// MARK: - Widget

struct QuickCommandWidget: Widget {
    let kind = "QuickCommandWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCommandProvider()) { entry in
            QuickCommandWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Commands")
        .description("Your pinned commands at a glance.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
        ])
    }
}

// MARK: - Views

struct QuickCommandWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuickCommandEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                rectangularView
            case .accessoryCircular:
                circularView
            default:
                circularView
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                Text("Quick Commands")
                    .font(.system(size: 11, weight: .semibold))
            }

            if entry.pinnedCommands.isEmpty {
                Text("No pinned commands")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.pinnedCommands.prefix(3)) { cmd in
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.yellow)
                        Text(cmd.label)
                            .font(.system(size: 10))
                            .lineLimit(1)
                        Spacer()
                        Text(cmd.serverName)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            VStack(spacing: 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                Text("\(entry.pinnedCommands.count)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
            }
        }
    }
}

#Preview(as: .accessoryRectangular) {
    QuickCommandWidget()
} timeline: {
    QuickCommandEntry(date: .now, pinnedCommands: [
        PinnedCommandInfo(label: "Restart API", serverName: "prod"),
        PinnedCommandInfo(label: "Check Disk", serverName: "db"),
        PinnedCommandInfo(label: "View Logs", serverName: "prod"),
    ])
}
