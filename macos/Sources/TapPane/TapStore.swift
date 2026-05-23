import Foundation
import Observation
import SwiftUI
import TapShared

/// Single source of truth for Tap's runtime state — server list,
/// auth, in-flight command, recent execution history. Ported from
/// the prior `AppState` (ObservableObject + @Published) to the
/// post-iOS 17 `@Observable` macro so views just `@Bindable var
/// store` instead of `@EnvironmentObject`.
///
/// Crucially: every mutation that the widget cares about
/// (sign-in/out, server CRUD, command CRUD, execute result) ends in
/// a call to `publishWidgetSnapshot()` — that's how the desktop
/// widget gets updated totals + the "Last run" line + the per-server
/// status dots. WidgetCenter.reloadAllTimelines() is hidden inside
/// `TapStateStore.write(_:)` so the call is cheap.
@MainActor
@Observable
final class TapStore {
    var isAuthenticated = false
    var servers: [Server] = []
    var isLoading = false
    var errorMessage: String?
    var selectedServer: Server?

    /// Last N executions in reverse-chronological order (most
    /// recent first). Surfaces the "Last run" widget line and feeds
    /// the recent-commands list the Commands widget renders.
    private(set) var recentExecutions: [ExecRecord] = []
    private static let recentLimit = 16

    @ObservationIgnored let apiClient = APIClient()
    @ObservationIgnored private let keychain = KeychainService()

    init() {}

    // MARK: Lifecycle

    /// Called by `paneStart()`: if a token is already on disk, sign
    /// the user in transparently and pull the latest config.
    func bootstrap() async {
        if let token = keychain.getToken() {
            apiClient.setToken(token)
            isAuthenticated = true
            do {
                let config = try await apiClient.getConfig()
                servers = config.servers
                publishWidgetSnapshot()
            } catch TapError.httpError(401) {
                signOut()
            } catch {
                errorMessage = "Failed to load servers: \(error.localizedDescription)"
                publishWidgetSnapshot()  // still publish so widget knows we tried
            }
        } else {
            publishWidgetSnapshot()  // signedIn=false placeholder
        }
    }

    // MARK: Auth

    func signInWithApple(identityToken: String,
                         userIdentifier: String,
                         email: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await apiClient.signInWithApple(
                identityToken: identityToken,
                userIdentifier: userIdentifier,
                email: email
            )
            keychain.saveToken(response.token)
            apiClient.setToken(response.token)
            isAuthenticated = true
            await loadConfig()
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func signOut() {
        keychain.deleteToken()
        apiClient.setToken(nil)
        isAuthenticated = false
        servers = []
        selectedServer = nil
        recentExecutions = []
        publishWidgetSnapshot()
    }

    // MARK: Config + servers

    func loadConfig() async {
        isLoading = true
        do {
            let config = try await apiClient.getConfig()
            servers = config.servers
            if let selected = selectedServer {
                selectedServer = servers.first(where: { $0.id == selected.id })
            }
            publishWidgetSnapshot()
        } catch {
            errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func provisionServer(host: String, port: Int, username: String,
                         password: String, name: String,
                         commands: [NewCommand]?) async throws
                         -> ProvisionResponse {
        let response = try await apiClient.provisionServer(
            host: host, port: port, username: username,
            password: password, name: name, commands: commands
        )
        await loadConfig()
        return response
    }

    func deleteServer(_ server: Server) async {
        do {
            try await apiClient.deleteServer(id: server.id)
            await loadConfig()
        } catch {
            errorMessage = "Failed to delete server: \(error.localizedDescription)"
        }
    }

    // MARK: Commands

    func executeCommand(serverId: String,
                        commandId: String) async throws -> ExecResponse {
        let serverName = servers.first { $0.id == serverId }?.name ?? "server"
        let commandLabel = servers.flatMap { $0.commands ?? [] }
            .first { $0.id == commandId }?.label ?? "command"
        do {
            let result = try await apiClient.executeCommand(
                serverId: serverId, commandId: commandId
            )
            recordExec(commandId: commandId, commandLabel: commandLabel,
                       serverId: serverId, serverName: serverName,
                       success: (result.exitCode ?? 0) == 0)
            return result
        } catch {
            recordExec(commandId: commandId, commandLabel: commandLabel,
                       serverId: serverId, serverName: serverName,
                       success: false)
            throw error
        }
    }

    /// Widget-button entry point — fire-and-forget, errors surface
    /// via `errorMessage` rather than being thrown back to a no-UI
    /// caller.
    func executeCommandByID(_ commandId: String) {
        // Find the command in any server's command list.
        guard let server = servers.first(where: {
            ($0.commands ?? []).contains(where: { $0.id == commandId })
        }) else {
            errorMessage = "Command not found — refresh and try again."
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.executeCommand(
                    serverId: server.id, commandId: commandId
                )
            } catch {
                self.errorMessage = "Execute failed: \(error.localizedDescription)"
            }
        }
    }

    func executeAdhoc(serverId: String,
                      command: String) async throws -> ExecResponse {
        try await apiClient.executeAdhoc(serverId: serverId, command: command)
    }

    func createCommand(serverId: String, name: String,
                       command: String,
                       description: String?) async throws {
        try await apiClient.createCommand(
            serverId: serverId, name: name,
            command: command, description: description
        )
        await loadConfig()
    }

    func deleteCommand(id: String) async throws {
        try await apiClient.deleteCommand(id: id)
        await loadConfig()
    }

    // MARK: Keys

    func getKeys() async throws -> [SSHKey] { try await apiClient.getKeys() }
    func generateKey() async throws -> GenerateKeyResponse {
        try await apiClient.generateKey()
    }

    // MARK: Recent executions

    struct ExecRecord: Identifiable, Equatable {
        let id = UUID()
        let commandId: String
        let commandLabel: String
        let serverId: String
        let serverName: String
        let success: Bool
        let at: Date
    }

    private func recordExec(commandId: String, commandLabel: String,
                            serverId: String, serverName: String,
                            success: Bool) {
        recentExecutions.insert(
            ExecRecord(commandId: commandId, commandLabel: commandLabel,
                       serverId: serverId, serverName: serverName,
                       success: success, at: Date()),
            at: 0
        )
        if recentExecutions.count > Self.recentLimit {
            recentExecutions = Array(recentExecutions.prefix(Self.recentLimit))
        }
        publishWidgetSnapshot()
    }

    // MARK: Widget snapshot

    /// Flatten the rich `Server` / `Command` models into the widget
    /// wire format and write to the App Group container. Called
    /// from every mutation method.
    func publishWidgetSnapshot() {
        let widgetServers = servers.map {
            WidgetServer(
                id: $0.id, name: $0.name, host: $0.host,
                online: $0.widgetOnline, latencyMs: $0.latencyMs
            )
        }
        // The Commands widget shows recently-used commands first,
        // with pinned commands as a fallback when the user hasn't
        // executed anything yet. Cap at `recentCapacity` for the
        // widget; the medium tile only renders the first 4.
        let widgetCommands = buildRecentCommandList()

        let snapshot = SharedTapState(
            signedIn: isAuthenticated,
            servers: widgetServers,
            recentCommands: widgetCommands,
            lastSyncedAt: Date(),
            lastExec: recentExecutions.first.map {
                WidgetExecResult(
                    commandLabel: $0.commandLabel,
                    serverName: $0.serverName,
                    success: $0.success,
                    at: $0.at
                )
            }
        )
        TapStateStore.write(snapshot)
    }

    private func buildRecentCommandList() -> [WidgetCommand] {
        // 1. Recent executions first (preserve order, dedupe by command id).
        var seen: Set<String> = []
        var out: [WidgetCommand] = []
        for record in recentExecutions {
            guard !seen.contains(record.commandId) else { continue }
            seen.insert(record.commandId)
            out.append(WidgetCommand(
                id: record.commandId,
                serverId: record.serverId,
                serverName: record.serverName,
                label: record.commandLabel
            ))
            if out.count >= SharedTapState.recentCapacity { return out }
        }
        // 2. Pad with pinned commands across all servers.
        for server in servers {
            for command in (server.commands ?? [])
                where (command.pinned ?? false) && !seen.contains(command.id) {
                seen.insert(command.id)
                out.append(WidgetCommand(
                    id: command.id,
                    serverId: server.id,
                    serverName: server.name,
                    label: command.label
                ))
                if out.count >= SharedTapState.recentCapacity { return out }
            }
        }
        // 3. Pad with any other commands (so a fresh user with no
        // executions and no pinned commands still sees something).
        for server in servers {
            for command in (server.commands ?? []) where !seen.contains(command.id) {
                seen.insert(command.id)
                out.append(WidgetCommand(
                    id: command.id,
                    serverId: server.id,
                    serverName: server.name,
                    label: command.label
                ))
                if out.count >= SharedTapState.recentCapacity { return out }
            }
        }
        return out
    }
}
