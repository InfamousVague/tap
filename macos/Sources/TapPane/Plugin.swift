import AppKit
import SwiftUI
import SuiteKit
import TapShared

/// Tap as a SuiteKit pane. Owns the `TapStore`, vends the menu-bar
/// glyph + popover view, and is the single seam the launcher (and
/// the standalone host shim) talks to.
@MainActor
public final class TapPaneProvider: NSObject, SuitePane {
    private let store = TapStore()

    /// Called whenever the menu-bar glyph should change. Tap toggles
    /// between the idle plug and a tinted active variant only if you
    /// add streaming command status later — for now it's stable.
    public var onMenuBarImageChange: ((NSImage) -> Void)?

    public override init() {
        super.init()
    }

    // MARK: SuitePane

    public var suiteABIVersion: Int { SuiteKitABI.current }
    public var paneID: String { "tap" }
    public var paneTitle: String { "TAP" }
    /// Cyan — `#06B6D4`. Distinct from Alfred's blue / Stats' pink /
    /// Quarantine's amber so the launcher's segmented switcher
    /// keeps Tap visually identifiable in the row of pane chips.
    public var paneTintHex: String { "#06B6D4" }

    public func paneMenuBarImage() -> NSImage {
        // `bolt.horizontal.circle` reads as "instant remote action"
        // which is what Tap does. Template image — the menu-bar
        // tints it; in the popover header it gets the cyan accent.
        let img = NSImage(
            systemSymbolName: "bolt.horizontal.circle",
            accessibilityDescription: "Tap"
        ) ?? NSImage()
        img.isTemplate = true
        return img
    }

    public func paneMakeView() -> NSView {
        // The store is the environment object every popover view
        // binds against. SwiftUI's `@Observable` reflection makes
        // a single Environment(_:) injection enough — no need for a
        // top-level @StateObject.
        NSHostingView(rootView: ContentView().environment(store))
    }

    public func paneStart() {
        // Bootstrap fires the keychain-token sign-in transparently
        // and writes the first widget snapshot. Done as a detached
        // task because paneStart is sync; nothing downstream blocks
        // on the result.
        Task { @MainActor in
            await store.bootstrap()
        }

        // Bridge widget intents → store. Two-track: the host's local
        // `IntentBus.shared` (fires when `openAppWhenRun = true`
        // launches us with an intent in flight) plus Darwin
        // `WidgetSignal` (fires regardless of which process the
        // intent ran in, so the launcher's hosted pane sees it too).
        IntentBus.shared.register(
            refresh: { [weak self] in
                Task { @MainActor in await self?.store.loadConfig() }
            },
            executeCommand: { [weak self] id in
                self?.store.executeCommandByID(id)
            }
        )
        subscribeToTapRefresh { [weak self] in
            Task { @MainActor in await self?.store.loadConfig() }
        }
        // We also need an observer for every known command id. The
        // store handles "which command id can be executed" via its
        // own lookup; we just need to know which ids exist so the
        // CFNotificationCenter has explicit observers (it doesn't
        // support glob matching). Subscribe after the first config
        // load lands — see `setupExecuteObservers` below.
        // (Lazy registration on first command list arrival.)
    }

    public func paneStop() {
        // No teardown needed — Darwin observers are process-scoped,
        // and the store's URLSession tasks cancel themselves when
        // the process exits.
    }
}

/// SuiteKit entry point. The launcher dlopens this symbol from
/// `/Applications/Tap.app/Contents/Frameworks/libTapPane.dylib`,
/// casts the returned object to `SuitePane`, and shows it in its
/// unified popover. `MainActor.assumeIsolated` is fine here because
/// the launcher calls this from its main actor (see SuiteKit ABI).
@_cdecl("suitePaneCreate")
public func suitePaneCreate() -> Unmanaged<AnyObject> {
    MainActor.assumeIsolated {
        Unmanaged.passRetained(TapPaneProvider())
    }
}
