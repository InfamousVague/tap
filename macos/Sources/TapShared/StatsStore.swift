import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Read/write helper for `SharedTapState` in the App Group
/// container. The host (TapPane) calls `write(_:)` whenever the
/// server list, command list, or last-exec changes; the widget
/// extension's TimelineProvider calls `read()` on each refresh.
///
/// Both sides use ISO-8601 dates so the wire format is stable across
/// app builds and easy to inspect on disk. Reader and writer use
/// matching strategies — a mismatch (writer ISO-8601 + reader
/// default-Double) silently fails the whole decode and the widget
/// falls back to placeholder, which is exactly the bug that bit the
/// Alfred build before this file's pattern was adopted.
public enum TapStateStore {
    private static let filename = "tap-state.json"

    private static var fileURL: URL {
        if let g = AppGroup.containerURL {
            return g.appendingPathComponent(filename)
        }
        // Dev fallback for `swift run` builds without the App Group
        // entitlement. The widget still won't see this file (it's in
        // the host's Application Support, not the Group Container)
        // but the host can at least round-trip its own writes.
        let support = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)) ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = support.appendingPathComponent("com.mattssoftware.tap")
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    public static func read() -> SharedTapState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let s = try? dec.decode(SharedTapState.self, from: data)
        else { return nil }
        // Defensive: a future Tap with a newer schema shouldn't crash
        // an older widget. Treat as "no payload yet" instead of
        // showing partial / wrong data.
        guard s.version <= SharedTapState.currentVersion else { return nil }
        return s
    }

    public static func write(_ state: SharedTapState) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)

        // Kick the timelines so the desktop widget redraws right
        // after a server/command/exec changes things. Apple
        // throttles this to ~once every few seconds either way; we
        // don't need our own debounce.
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
