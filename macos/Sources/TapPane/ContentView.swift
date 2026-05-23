import SwiftUI
import TapShared

/// Top-level popover view. Two states:
///   • Not signed in → SignInView (Sign in with Apple button)
///   • Signed in     → ServerListView (expandable server rows with
///                     commands underneath, plus footer actions)
///
/// Width is 340pt to match every other merged pane and the
/// launcher's unified popover envelope. Was 380pt up through
/// v2.0.0, but the launcher consolidated everything to 340pt
/// when the APPS grid shrank to 4×48pt tiles in launcher
/// v0.2.19, so a 380pt Tap drew its content outside the
/// popover chrome on the right side. Height matches the
/// launcher's pane area (540 total minus tabs ≈ ours, kept at
/// 540 since standalone NSPopover sizes to fit anyway).
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
        .frame(width: 340, height: 540)
        // No explicit background — let the launcher popover's
        // material (and the standalone NSPopover's translucent
        // chrome) show through, matching every other suite pane.
        // The previous `Color.stashBgPrimary` painted an opaque
        // black rectangle that visually disconnected Tap from the
        // rest of the carousel.
    }
}
