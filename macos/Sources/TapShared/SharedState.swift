import Foundation

/// Compact, widget-friendly snapshot of Tap state. Written by the
/// host (TapPane) whenever the server list, command list, or
/// execution history changes; read by the widget timeline provider
/// on every refresh.
///
/// Kept deliberately small — only what the widget actually renders.
/// Adding fields is cheap thanks to the explicit Codable init below
/// (defaults keep older readers working), but every byte here is
/// re-serialised on each scan/exec so don't pile on.
public struct SharedTapState: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    public var version: Int

    public var signedIn: Bool

    /// Compact server view for the widget. The host already has
    /// rich `Server` models in TapPane; we flatten to just what the
    /// widget renders so the widget doesn't need to link the full
    /// TapPane module.
    public var servers: [WidgetServer]

    /// The "show in the widget tile" command list: pinned + most
    /// recently executed, capped at `recentCapacity`. The medium
    /// Commands widget shows the first 4. Each entry carries its
    /// own server id so the widget button knows where to execute.
    public static let recentCapacity = 8
    public var recentCommands: [WidgetCommand]

    /// Last successful config fetch. Widget surface shows a "stale"
    /// badge if this is older than ~5 minutes.
    public var lastSyncedAt: Date?

    /// Last execution outcome, for the Commands widget "Last run"
    /// strip. Nil before the first exec.
    public var lastExec: WidgetExecResult?

    public init(
        version: Int = SharedTapState.currentVersion,
        signedIn: Bool = false,
        servers: [WidgetServer] = [],
        recentCommands: [WidgetCommand] = [],
        lastSyncedAt: Date? = nil,
        lastExec: WidgetExecResult? = nil
    ) {
        self.version = version
        self.signedIn = signedIn
        self.servers = servers
        self.recentCommands = recentCommands
        self.lastSyncedAt = lastSyncedAt
        self.lastExec = lastExec
    }

    // Explicit decoding so adding new fields stays backwards-compat:
    // an old payload on disk + a new widget binary read both work
    // because every field has a sensible default.
    private enum CodingKeys: String, CodingKey {
        case version, signedIn, servers, recentCommands
        case lastSyncedAt, lastExec
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
            ?? SharedTapState.currentVersion
        signedIn = try c.decodeIfPresent(Bool.self, forKey: .signedIn) ?? false
        servers = try c.decodeIfPresent([WidgetServer].self,
                                        forKey: .servers) ?? []
        recentCommands = try c.decodeIfPresent([WidgetCommand].self,
                                               forKey: .recentCommands) ?? []
        lastSyncedAt = try c.decodeIfPresent(Date.self,
                                             forKey: .lastSyncedAt)
        lastExec = try c.decodeIfPresent(WidgetExecResult.self,
                                         forKey: .lastExec)
    }

    /// Synthetic snapshot for `Provider.placeholder` and first
    /// launch (before the user has signed in / scanned).
    public static let placeholder = SharedTapState(
        signedIn: false,
        servers: [
            WidgetServer(id: "demo-1", name: "production",
                         host: "203.0.113.10", online: true, latencyMs: 42),
            WidgetServer(id: "demo-2", name: "staging",
                         host: "203.0.113.11", online: true, latencyMs: 88)
        ],
        recentCommands: [
            WidgetCommand(id: "c1", serverId: "demo-1",
                          serverName: "production", label: "Deploy"),
            WidgetCommand(id: "c2", serverId: "demo-1",
                          serverName: "production", label: "Restart"),
            WidgetCommand(id: "c3", serverId: "demo-2",
                          serverName: "staging", label: "Logs")
        ],
        lastSyncedAt: nil,
        lastExec: nil
    )
}

/// Flat per-server snapshot consumed by the widget. Decoupled from
/// TapPane's full `Server` struct — the widget extension never links
/// TapPane, so we ship a minimal schema and let the host pre-roll
/// status into the flags below.
public struct WidgetServer: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let host: String
    /// Host has decided "this server is reachable right now" — used
    /// for the green/gray status dot. Mapped from the relay's
    /// `status` string ("ok" → true).
    public let online: Bool
    /// Latest measured latency, ms. Nil if never measured or the
    /// server is offline.
    public let latencyMs: Int?

    public init(id: String, name: String, host: String,
                online: Bool, latencyMs: Int?) {
        self.id = id
        self.name = name
        self.host = host
        self.online = online
        self.latencyMs = latencyMs
    }
}

/// One row in the Commands widget. Holds the IDs the widget's
/// `Button(intent: ExecuteCommandIntent(commandId:))` needs to fire
/// the right exec, plus enough display text to render the row
/// without a second App Group read.
public struct WidgetCommand: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let serverId: String
    public let serverName: String
    public let label: String

    public init(id: String, serverId: String,
                serverName: String, label: String) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.label = label
    }
}

/// Compact execution outcome for the widget's last-run line.
public struct WidgetExecResult: Codable, Sendable, Equatable {
    public let commandLabel: String
    public let serverName: String
    public let success: Bool
    public let at: Date
    public init(commandLabel: String, serverName: String,
                success: Bool, at: Date) {
        self.commandLabel = commandLabel
        self.serverName = serverName
        self.success = success
        self.at = at
    }
}
