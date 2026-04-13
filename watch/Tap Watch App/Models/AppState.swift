import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var servers: [Server] = []
    @Published var overviews: [String: ServerOverview] = [:]  // keyed by server ID
    @Published var isLoading: Bool = false
    @Published var isLoadingOverview: Bool = false
    @Published var error: String?
    private let keychain = KeychainService.shared
    private var apiClient: APIClient?

    init() {
        // Just check keychain — don't do any network calls during init
        if let url = keychain.getRelayURL(),
           let token = keychain.getToken(),
           !url.isEmpty, !token.isEmpty {
            self.apiClient = APIClient(baseURL: url, token: token)
            self.isConfigured = true
        }
    }

    func signInWithApple(identityToken: String, userIdentifier: String, email: String?) async {
        let url = AppConfig.relayURL
        guard let requestURL = URL(string: "\(url)/auth/apple") else { return }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "identity_token": identityToken,
            "user_identifier": userIdentifier,
            "email": email ?? ""
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let token = json?["token"] as? String else { return }
            configure(relayURL: url, token: token)
            HapticService.shared.play(.success)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func configure(relayURL: String, token: String) {
        keychain.setRelayURL(relayURL)
        keychain.setToken(token)
        self.apiClient = APIClient(baseURL: relayURL, token: token)
        self.isConfigured = true
    }

    func disconnect() {
        keychain.setRelayURL("")
        keychain.setToken("")
        self.apiClient = nil
        self.isConfigured = false
        self.servers = []
    }

    func refreshConfig() async {
        guard let client = apiClient else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let config = try await client.getConfig()
            self.servers = config.servers
            self.error = nil
            // Write server status to shared UserDefaults for widget
            syncServerStatusToWidget()
        } catch APIError.unauthorized {
            // Token expired — force re-auth
            disconnect()
        } catch {
            self.error = error.localizedDescription
            print("[Tap] Config refresh failed: \(error)")
        }
    }

    func refreshOverview() async {
        guard let client = apiClient else { return }
        isLoadingOverview = true
        defer { isLoadingOverview = false }

        do {
            let overviewList = try await client.getOverview()
            var map: [String: ServerOverview] = [:]
            for o in overviewList {
                map[o.serverId] = o
            }
            self.overviews = map
            syncOverviewToWidget()
            print("[Tap] Overview loaded: \(overviewList.count) servers")
        } catch let error as APIError {
            print("[Tap] Overview API error: \(error)")
        } catch let error as DecodingError {
            print("[Tap] Overview decode error: \(error)")
        } catch {
            print("[Tap] Overview fetch failed: \(error)")
        }
    }

    func overview(for serverId: String) -> ServerOverview? {
        overviews[serverId]
    }

    /// Write server health data to shared UserDefaults so the widget can read it
    private func syncServerStatusToWidget() {
        guard let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp") else {
            print("[Tap] Widget sync FAILED: could not open shared UserDefaults")
            return
        }
        let total = servers.count
        let up = servers.filter { $0.status == .up }.count
        let down = servers.filter { $0.status == .down }.count
        let downNames = servers.filter { $0.status == .down }.map { $0.name }
        defaults.set(total, forKey: "widget_total_servers")
        defaults.set(up, forKey: "widget_up_servers")
        defaults.set(down, forKey: "widget_down_servers")
        defaults.set(downNames, forKey: "widget_down_names")
        // Sync pinned commands as JSON array of {"label":"...","serverName":"..."}
        var pinned: [[String: String]] = []
        for server in servers {
            for cmd in server.commands where cmd.pinned {
                pinned.append(["label": cmd.label, "serverName": server.name])
            }
        }
        if let data = try? JSONEncoder().encode(Array(pinned.prefix(4))) {
            defaults.set(data, forKey: "widget_pinned_commands")
        }

        defaults.set(Date().timeIntervalSince1970, forKey: "widget_last_updated")
        defaults.synchronize()
        print("[Tap] Widget sync: \(total) total, \(up) up, \(down) down")
    }

    /// Write overview metrics to shared UserDefaults for metric widgets
    private func syncOverviewToWidget() {
        guard let defaults = UserDefaults(suiteName: "group.com.mattssoftware.tap.watchkitapp") else { return }

        // Encode overview array as JSON for the widget
        struct WidgetOverview: Codable {
            let serverId: String
            let serverName: String
            let status: String
            let diskPercent: Int?
            let memPercent: Int?
            let load1: Double?
            let uptime: String?
            let dockerRunning: Int?
            let dockerTotal: Int?
        }

        let items = overviews.values.map { o in
            WidgetOverview(
                serverId: o.serverId,
                serverName: o.serverName,
                status: o.status,
                diskPercent: o.disk?.usePercent,
                memPercent: o.memory?.usePercent,
                load1: o.load?.first,
                uptime: o.uptime,
                dockerRunning: o.dockerRunning,
                dockerTotal: o.dockerTotal
            )
        }

        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: "widget_overviews")
        }
        defaults.synchronize()
    }

    func executeCommand(serverId: String, commandId: String) async -> ExecResult? {
        guard let client = apiClient else { return nil }
        do {
            let result = try await client.execute(serverId: serverId, commandId: commandId)
            HapticService.shared.play(result.status == "success" ? .success : .failure)
            return result
        } catch {
            HapticService.shared.play(.failure)
            self.error = error.localizedDescription
            return nil
        }
    }

    func pingServer(serverId: String) async -> PingResult? {
        guard let client = apiClient else { return nil }
        return try? await client.ping(serverId: serverId)
    }
}
