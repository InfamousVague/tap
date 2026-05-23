import Foundation

/// HTTPS client for tap.mattssoftware.com. Same wire format as the
/// Watch / iOS / Mac builds (the relay enforces it server-side); we
/// just need a Bearer-token-on-every-request flow, decode the
/// known response shapes from `Models.swift`, and surface failures
/// as `TapError` so the UI can show readable messages.
final class APIClient {
    private let baseURL = "https://tap.mattssoftware.com"
    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: Auth

    func signInWithApple(
        identityToken: String,
        userIdentifier: String,
        email: String?
    ) async throws -> AuthResponse {
        var body: [String: Any] = [
            "identity_token": identityToken,
            "user_identifier": userIdentifier
        ]
        if let email { body["email"] = email }
        return try await post("/auth/apple", body: body)
    }

    // MARK: Config

    func getConfig() async throws -> ConfigResponse {
        try await get("/config")
    }

    // MARK: Servers

    func provisionServer(
        host: String, port: Int, username: String, password: String,
        name: String, commands: [NewCommand]?
    ) async throws -> ProvisionResponse {
        var body: [String: Any] = [
            "host": host, "port": port, "username": username,
            "password": password, "name": name
        ]
        if let commands {
            body["commands"] = commands.map { cmd -> [String: Any] in
                var d: [String: Any] = ["label": cmd.name, "command": cmd.command]
                if let desc = cmd.description { d["description"] = desc }
                return d
            }
        }
        return try await post("/setup/provision", body: body)
    }

    func createServer(name: String, host: String, port: Int,
                      username: String) async throws -> Server {
        try await post("/servers", body: [
            "name": name, "host": host, "port": port, "username": username
        ])
    }

    func deleteServer(id: String) async throws {
        try await delete("/servers/\(id)")
    }

    // MARK: Commands

    func createCommand(serverId: String, name: String,
                       command: String,
                       description: String?,
                       confirm: Bool? = nil) async throws {
        // `confirm` defaults to the relay's NewCommand default
        // (true) when we don't send it. Pass false explicitly for
        // safe read-only presets so they don't require a confirm
        // tap on every run; pass true for destructive ones. Custom
        // commands omit it and inherit the safe-by-default `true`.
        var body: [String: Any] = ["label": name, "command": command]
        if let confirm { body["confirm"] = confirm }
        let _: Command = try await post(
            "/servers/\(serverId)/commands", body: body
        )
    }

    func deleteCommand(id: String) async throws {
        try await delete("/commands/\(id)")
    }

    // MARK: Execution

    func executeCommand(serverId: String,
                        commandId: String) async throws -> ExecResponse {
        try await post("/exec", body: [
            "server_id": serverId, "command_id": commandId
        ])
    }

    func executeAdhoc(serverId: String,
                      command: String) async throws -> ExecResponse {
        try await post("/exec/adhoc", body: [
            "server_id": serverId, "command": command
        ])
    }

    // MARK: Keys

    func getKeys() async throws -> [SSHKey] {
        let response: KeysResponse = try await get("/keys")
        return response.keys
    }

    func generateKey() async throws -> GenerateKeyResponse {
        try await post("/keys/generate", body: [:])
    }

    // MARK: HTTP helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "GET"
        addAuthHeader(&req)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String,
                                    body: [String: Any]) async throws -> T {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func delete(_ path: String) async throws -> Data {
        var req = URLRequest(url: URL(string: baseURL + path)!)
        req.httpMethod = "DELETE"
        addAuthHeader(&req)
        let (data, response) = try await URLSession.shared.data(for: req)
        try validateResponse(response, data: data)
        return data
    }

    private func addAuthHeader(_ request: inout URLRequest) {
        if let token {
            request.setValue("Bearer \(token)",
                             forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse,
                                  data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw TapError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder()
                .decode(APIError.self, from: data) {
                throw TapError.serverError(
                    apiError.error ?? apiError.message ?? "Unknown error"
                )
            }
            throw TapError.httpError(http.statusCode)
        }
    }
}
