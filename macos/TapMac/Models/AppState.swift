import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var servers: [Server] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedServer: Server?

    private let apiClient = APIClient()
    private let keychain = KeychainService()

    func checkAuth() async {
        if let token = keychain.getToken() {
            apiClient.setToken(token)
            isAuthenticated = true
            do {
                let config = try await apiClient.getConfig()
                servers = config.servers
                if let selected = selectedServer {
                    selectedServer = servers.first(where: { $0.id == selected.id })
                }
            } catch TapError.httpError(401) {
                // Token expired or invalid — force re-auth
                signOut()
            } catch {
                // Network/decode error but token might still be valid
                errorMessage = "Failed to load servers: \(error.localizedDescription)"
            }
        }
    }

    func signInWithApple(identityToken: String, userIdentifier: String, email: String?) async {
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
    }

    func loadConfig() async {
        isLoading = true
        do {
            let config = try await apiClient.getConfig()
            servers = config.servers
            // Refresh selected server if it exists
            if let selected = selectedServer {
                selectedServer = servers.first(where: { $0.id == selected.id })
            }
        } catch {
            errorMessage = "Failed to load config: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func provisionServer(host: String, port: Int, username: String, password: String, name: String, commands: [NewCommand]?) async throws -> ProvisionResponse {
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

    func executeCommand(serverId: String, commandId: String) async throws -> ExecResponse {
        return try await apiClient.executeCommand(serverId: serverId, commandId: commandId)
    }

    func executeAdhoc(serverId: String, command: String) async throws -> ExecResponse {
        return try await apiClient.executeAdhoc(serverId: serverId, command: command)
    }

    func createCommand(serverId: String, name: String, command: String, description: String?) async throws {
        try await apiClient.createCommand(serverId: serverId, name: name, command: command, description: description)
        await loadConfig()
    }

    func deleteCommand(id: String) async throws {
        try await apiClient.deleteCommand(id: id)
        await loadConfig()
    }

    func getKeys() async throws -> [SSHKey] {
        return try await apiClient.getKeys()
    }

    func generateKey() async throws -> GenerateKeyResponse {
        return try await apiClient.generateKey()
    }
}
