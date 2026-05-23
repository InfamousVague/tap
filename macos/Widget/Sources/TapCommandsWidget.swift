import WidgetKit
import SwiftUI
import TapShared

/// Tap Commands widget — the action-oriented variant. Small = server
/// count + refresh button. Medium = 4 most-recently-used or pinned
/// commands with one-tap `Button(intent: ExecuteCommandIntent)`.
struct TapCommandsWidget: Widget {
    let kind: String = "TapCommandsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TapProvider()) { entry in
            CommandsView(entry: entry)
                // Force `.accented` in our SwiftUI subtree so the
                // buttons + brand row read as the dimmed glass look
                // regardless of focus state. Same pattern Alfred /
                // Quarantine / Stats adopted — visually consistent
                // with the rest of the suite.
                .environment(\.widgetRenderingMode, .accented)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tap Commands")
        .description("One-tap execute for pinned and recent commands.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct CommandsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TapEntry

    var body: some View {
        switch family {
        case .systemSmall:  CommandsSmallView(entry: entry)
        case .systemMedium: CommandsMediumView(entry: entry)
        default:            CommandsSmallView(entry: entry)
        }
    }
}
