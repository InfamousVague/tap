import Foundation

/// Bridge between the AppIntents (defined in TapShared so both the
/// widget extension and the host can see them) and the running Tap
/// host process that does the actual work.
///
/// Both intents declare `openAppWhenRun = true`, so when the widget's
/// `Button(intent:)` fires, the system wakes / launches Tap and runs
/// `perform()` in the host process. `perform()` calls the closures
/// the host's `AppDelegate` registered at launch — `TapStore` ends
/// up driving the API call. No registered handlers → silent no-op
/// (rather than crash), which is what we want for the brief window
/// before the host's launch finishes.
///
/// `executeCommand` carries the command id forward verbatim; the
/// host looks the command up against its current `TapStore.servers`
/// model and decides what to do. The widget never has to know the
/// SSH-execute API surface.
@MainActor
public final class IntentBus {
    public static let shared = IntentBus()
    private init() {}

    private var refreshHandler: (@MainActor () -> Void)?
    private var executeHandler: (@MainActor (String) -> Void)?

    public func register(
        refresh: @escaping @MainActor () -> Void,
        executeCommand: @escaping @MainActor (String) -> Void
    ) {
        self.refreshHandler = refresh
        self.executeHandler = executeCommand
    }

    public func refresh() { refreshHandler?() }
    public func executeCommand(_ id: String) { executeHandler?(id) }
}
