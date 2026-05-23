import AppIntents

/// Widget-driven AppIntents.
///
/// Dispatch pattern matches the Alfred build: `openAppWhenRun = true`
/// → the system launches/wakes `Tap.app` to run `perform()` in the
/// host process, where `IntentBus.shared` (registered during the
/// host's launch) actually drives `TapStore`. We *also* post a Darwin
/// notification via `WidgetSignal`, so the launcher's hosted
/// `TapPane` can react without a second app launch when the launcher
/// owns the pane. Two-track means whichever flavour of Tap is alive
/// — standalone, merged, or both during the brief overlap — sees the
/// request.
///
/// `commandId` is the relay command UUID. The widget bakes the right
/// id into each `Button(intent: ExecuteCommandIntent(commandId:))`
/// when it builds the tile from `SharedTapState.recentCommands`.

public struct RefreshIntent: AppIntent {
    public static var title: LocalizedStringResource = "Refresh Tap"
    public static var description = IntentDescription(
        "Re-fetch the latest servers and commands from Tap relay."
    )
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.refresh()
        WidgetSignal.refresh.post()
        return .result()
    }
}

public struct ExecuteCommandIntent: AppIntent {
    public static var title: LocalizedStringResource = "Execute Tap Command"
    public static var description = IntentDescription(
        "Run a pre-configured command on its Tap server via SSH."
    )
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Command ID")
    public var commandId: String

    public init() { self.commandId = "" }
    public init(commandId: String) { self.commandId = commandId }

    @MainActor
    public func perform() async throws -> some IntentResult {
        IntentBus.shared.executeCommand(commandId)
        WidgetSignal.executeCommand(commandId).post()
        return .result()
    }
}
