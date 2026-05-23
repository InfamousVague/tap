import WidgetKit
import SwiftUI

/// `@main` for the Tap widget extension. The bundle is what
/// WidgetKit enumerates to populate the macOS widget gallery —
/// dropping another widget in later means appending it here. Two
/// widgets ship today:
///
///   • TapCommandsWidget — one-tap execute on pinned / recent
///     commands (small = server count + refresh, medium = 4 commands
///     with `Button(intent: ExecuteCommandIntent)`).
///
///   • TapStatusWidget — observational dashboard of every server's
///     online/offline status + latency.
@main
struct TapWidgetBundle: WidgetBundle {
    var body: some Widget {
        TapCommandsWidget()
        TapStatusWidget()
    }
}
