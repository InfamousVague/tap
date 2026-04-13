import AppIntents

// MARK: - "Hey Siri, Tap restart prod-api"

struct RunCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Tap Command"
    static var description = IntentDescription("Run a command on a remote server via Tap")

    @Parameter(title: "Command")
    var commandLabel: String

    @Parameter(title: "Server")
    var serverName: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Run \(\.$commandLabel) on \(\.$serverName)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Look up command by label across servers
        guard let url = KeychainService.shared.getRelayURL(),
              let token = KeychainService.shared.getToken() else {
            return .result(dialog: "Tap isn't configured yet. Open the app to set up your relay.")
        }

        let client = APIClient(baseURL: url, token: token)
        let config = try await client.getConfig()

        // Find matching command
        var matchedServer: Server?
        var matchedCommand: Command?

        for server in config.servers {
            if let name = serverName, !server.name.localizedCaseInsensitiveContains(name) {
                continue
            }
            if let cmd = server.commands.first(where: { $0.label.localizedCaseInsensitiveContains(commandLabel) }) {
                matchedServer = server
                matchedCommand = cmd
                break
            }
        }

        guard let server = matchedServer, let command = matchedCommand else {
            return .result(dialog: "Couldn't find a command matching \"\(commandLabel)\".")
        }

        // Execute
        let result = try await client.execute(serverId: server.id, commandId: command.id)

        if result.isSuccess {
            HapticService.shared.play(.success)
            return .result(dialog: "\(command.label) on \(server.name) completed successfully in \(result.durationMs)ms.")
        } else {
            HapticService.shared.play(.failure)
            return .result(dialog: "\(command.label) failed with exit code \(result.exitCode ?? -1).")
        }
    }
}

// MARK: - "Hey Siri, check my servers on Tap"

struct CheckServersIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Server Status"
    static var description = IntentDescription("Check the health of all servers on Tap")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let url = KeychainService.shared.getRelayURL(),
              let token = KeychainService.shared.getToken() else {
            return .result(dialog: "Tap isn't configured yet.")
        }

        let client = APIClient(baseURL: url, token: token)
        let config = try await client.getConfig()

        let total = config.servers.count
        let up = config.servers.filter { $0.status == .up }.count
        let down = total - up

        if down == 0 {
            return .result(dialog: "All \(total) servers are online.")
        } else {
            let downServers = config.servers.filter { $0.status != .up }.map { $0.name }.joined(separator: ", ")
            return .result(dialog: "\(up) of \(total) servers online. Down: \(downServers)")
        }
    }
}

// MARK: - Shortcuts Provider

struct TapShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunCommandIntent(),
            phrases: [
                "Run a command with \(.applicationName)",
            ],
            shortTitle: "Run Command",
            systemImageName: "terminal"
        )
        AppShortcut(
            intent: CheckServersIntent(),
            phrases: [
                "Check my servers with \(.applicationName)",
                "\(.applicationName) server status",
            ],
            shortTitle: "Check Servers",
            systemImageName: "server.rack"
        )
    }
}
