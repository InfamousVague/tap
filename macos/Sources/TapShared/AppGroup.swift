import Foundation

/// One source of truth for the App Group id used by the host
/// (Tap / TapPane) and the widget extension to share the widget
/// snapshot. **Must match the
/// `com.apple.security.application-groups` entitlement value in
/// `Tap.entitlements` and `TapWidgets.entitlements`** — if any of
/// these three drift, the Group Container resolves to `nil` and the
/// widget silently shows the placeholder instead of live data.
///
/// macOS requires App Group ids to be team-prefixed (`F6ZAL7ANAD.`)
/// — `containermanagerd` rejects unprefixed ids at runtime ("Group
/// containers identifiers should be prefixed by requestor's team
/// ID"). iOS doesn't enforce this convention, which is why it
/// catches people porting iOS widget code.
public enum AppGroup {
    public static let id = "F6ZAL7ANAD.group.com.mattssoftware.tap"

    /// Resolved Group Container directory, or `nil` if the bundle
    /// isn't entitled (e.g. `swift run` builds without the App
    /// Group). Callers fall back to Application Support in that
    /// case so dev iteration still works — the widget just won't
    /// see the data.
    public static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: id
        )
    }
}
