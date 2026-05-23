import WidgetKit
import SwiftUI
import TapShared

/// Tap Status widget — observational dashboard. No execute buttons;
/// the surface shows online/offline + latency. Small = hero "N/M
/// online" pair. Medium = scrollable list of servers with a green/
/// red status dot per row.
struct TapStatusWidget: Widget {
    let kind: String = "TapStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TapProvider()) { entry in
            StatusView(entry: entry)
                .environment(\.widgetRenderingMode, .accented)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tap Status")
        .description("Online/offline health for every Tap server.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct StatusView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TapEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  StatusSmallView(entry: entry)
            case .systemMedium: StatusMediumView(entry: entry)
            default:            StatusSmallView(entry: entry)
            }
        }
        // Desktop-widget tap target. Routes to the MattsSoftware
        // launcher's `application(_:open:)` handler which parses
        // the host segment (`tap`) and pops the popover already
        // switched to the Tap pane. Required because menu-bar
        // agents don't surface UI on bundle-id launch — without
        // a URL hook, tapping the widget appears to do nothing.
        .widgetURL(URL(string: "mattssoftware://tap"))
    }
}

// MARK: - Small

struct StatusSmallView: View {
    let entry: TapEntry

    private var onlineCount: Int {
        entry.state.servers.filter(\.online).count
    }
    private var totalCount: Int { entry.state.servers.count }

    var body: some View {
        VStack(spacing: 4) {
            Text("TAP · STATUS")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            Text("\(onlineCount)/\(totalCount)")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                // Wrap each branch in `AnyShapeStyle` because the
                // ternary mixes `HierarchicalShapeStyle.secondary`
                // and concrete `Color` values — Swift won't infer
                // a common type otherwise. Color values stand in
                // for the "all green / some yellow / all red"
                // traffic-light at-a-glance signal.
                .foregroundStyle(
                    totalCount == 0
                        ? AnyShapeStyle(HierarchicalShapeStyle.secondary)
                        : onlineCount == totalCount
                            ? AnyShapeStyle(Color.green)
                            : onlineCount > 0
                                ? AnyShapeStyle(Color.yellow)
                                : AnyShapeStyle(Color.red)
                )

            Text(totalCount == 0
                 ? "no servers"
                 : (onlineCount == totalCount
                    ? "all online" : "online"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .widgetAccentable()
                .lineLimit(1)

            if entry.isStale {
                Text("stale")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(14)
    }
}

// MARK: - Medium

struct StatusMediumView: View {
    let entry: TapEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("TAP · STATUS")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
                Spacer()
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("stale")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                }
            }

            if entry.state.servers.isEmpty {
                emptyBody
            } else {
                serversList
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private var emptyBody: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text(entry.state.signedIn
                 ? "No servers yet"
                 : "Sign in to Tap")
                .font(.system(size: 11, weight: .medium))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// Compact server rows. Caps at 5 — the medium tile is 158 pt
    /// tall, even 5 rows is a stretch when chrome is included.
    private var serversList: some View {
        VStack(spacing: 3) {
            ForEach(entry.state.servers.prefix(5)) { server in
                HStack(spacing: 8) {
                    Circle()
                        .fill(server.online ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(server.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    if let latency = server.latencyMs, server.online {
                        Text("\(latency)ms")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .widgetAccentable()
                    } else if !server.online {
                        Text("offline")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .widgetAccentable()
                    }
                }
            }
            if entry.state.servers.count > 5 {
                Text("+ \(entry.state.servers.count - 5) more")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .widgetAccentable()
            }
        }
    }
}
