import SwiftUI
import TapShared

/// Top-level popover view. Two states:
///   • Not signed in → SignInView (Sign in with Apple button)
///   • Signed in     → ServerListView (expandable server rows with
///                     commands underneath, plus footer actions)
///
/// Width is fixed to 380pt — comfortable for two-column command
/// rows and matches the visual proportion of the launcher's other
/// panes. Height grows up to ~520pt, then internal scroll views
/// take over.
struct ContentView: View {
    @Environment(TapStore.self) private var store

    var body: some View {
        Group {
            if store.isAuthenticated {
                ServerListView()
            } else {
                SignInView()
            }
        }
        .frame(width: 380, height: 520)
        // No explicit background — let the launcher popover's
        // material (and the standalone NSPopover's translucent
        // chrome) show through, matching every other suite pane.
        // The previous `Color.stashBgPrimary` painted an opaque
        // black rectangle that visually disconnected Tap from the
        // rest of the carousel.
    }
}
