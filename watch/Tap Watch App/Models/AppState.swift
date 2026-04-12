import SwiftUI
import SwiftData

@MainActor
class AppState: ObservableObject {
    @Published var isConfigured: Bool = false
    @Published var servers: [Server] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let keychain = KeychainService.shared
    private var apiClient: APIClient?

    init() {
        // Check if relay is configured
        if let url = keychain.getRelayURL(), let token = keychain.getToken() {
            self.apiClient = APIClient(baseURL: url, token: token)
            self.isConfigured = true
            Task { await refreshConfig() }
        }
    }

    func configure(relayURL: String, token: String) {
        keychain.setRelayURL(relayURL)
        keychain.setToken(token)
        self.apiClient = APIClient(baseURL: relayURL, token: token)
        self.isConfigured = true
        Task { await refreshConfig() }
    }

    func refreshConfig() async {
        guard let client = apiClient else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let config = try await client.getConfig()
            self.servers = config.servers
        } catch {
            self.error = error.localizedDescription
        }
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
