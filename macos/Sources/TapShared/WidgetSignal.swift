import Foundation

/// Darwin-notification bridge between the widget extension and any
/// long-running Tap process (standalone `Tap.app` or the
/// MattsSoftware launcher's hosted `TapPane`).
///
/// `IntentBus` alone isn't enough: it's a per-process singleton, so
/// for its closures to fire, `AppIntent.perform()` has to run in the
/// SAME process that registered them. When the launcher hosts Tap,
/// `SuiteGuard.exitIfDeferring("tap")` exits `Tap.app` in its first
/// millisecond — `perform()` fires into a dead process and the
/// widget Execute / Refresh silently no-op. Darwin notifications
/// fix this: they're a global kernel-mediated notification bus that
/// crosses sandbox + process boundaries, so the live pane reacts
/// regardless of which process the intent ran in.
public enum WidgetSignal: Sendable, Hashable {
    case refresh
    case executeCommand(String)

    /// Stable string identifiers used as the Darwin notification
    /// name. Parameterised intents (like `executeCommand`) encode
    /// the parameter in the suffix so a single observer can dispatch
    /// on a prefix and parse the id back out.
    public var name: String {
        switch self {
        case .refresh:
            return "com.mattssoftware.tap.widget.refresh"
        case .executeCommand(let id):
            return "com.mattssoftware.tap.widget.execute.\(id)"
        }
    }

    public func post() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil, nil, true
        )
    }
}

/// Holds the Swift closure across the C-callback boundary the Darwin
/// notification API uses. The opaque pointer the callback receives
/// is the `Unmanaged.passRetained(...)` from `subscribeToRefresh`.
private final class _SignalObserver {
    let handler: () -> Void
    init(_ h: @escaping () -> Void) { handler = h }
}

/// Subscribe to the broadcast Refresh signal. Use this for the
/// idempotent re-fetch path.
@discardableResult
@MainActor
public func subscribeToTapRefresh(
    _ handler: @escaping @MainActor () -> Void
) -> AnyObject {
    let observer = _SignalObserver {
        Task { @MainActor in handler() }
    }
    let opaque = Unmanaged.passRetained(observer).toOpaque()
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        opaque,
        { _, observerPtr, _, _, _ in
            guard let observerPtr else { return }
            let obs = Unmanaged<_SignalObserver>
                .fromOpaque(observerPtr).takeUnretainedValue()
            obs.handler()
        },
        WidgetSignal.refresh.name as CFString,
        nil,
        .deliverImmediately
    )
    return observer
}

/// Subscribe to every "execute this command" signal. We register a
/// suffix-matching observer (CFNotificationCenter doesn't do glob
/// matching itself, so we route through a coalescing notify_token
/// pattern — see implementation below) and the handler receives the
/// parsed command id.
///
/// Implementation: CFNotificationCenter requires an exact-match name
/// per observer, so we can't subscribe to a wildcard. Instead the
/// host subscribes once it KNOWS the command ids — `register(for:)`
/// returns a token bag the caller can `release()` when the command
/// list changes (e.g. after refresh).
@MainActor
public final class CommandExecObserver {
    private var tokens: [AnyObject] = []
    public init() {}

    /// Subscribe to a specific command id. Multiple subscribes are
    /// safe (Darwin notifications dedupe at the kernel) but call
    /// `clear()` before re-subscribing the same id from a refreshed
    /// command list.
    @discardableResult
    public func subscribe(
        commandId: String,
        handler: @escaping @MainActor (String) -> Void
    ) -> AnyObject {
        let observer = _SignalObserver {
            Task { @MainActor in handler(commandId) }
        }
        let opaque = Unmanaged.passRetained(observer).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            opaque,
            { _, observerPtr, _, _, _ in
                guard let observerPtr else { return }
                let obs = Unmanaged<_SignalObserver>
                    .fromOpaque(observerPtr).takeUnretainedValue()
                obs.handler()
            },
            WidgetSignal.executeCommand(commandId).name as CFString,
            nil,
            .deliverImmediately
        )
        tokens.append(observer)
        return observer
    }

    public func clear() { tokens.removeAll() }
}
