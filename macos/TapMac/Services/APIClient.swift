import Foundation

class APIClient {
    private let baseURL = "https://tap.mattssoftware.com"
    private var token: String?

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - Auth

    func signInWithApple(identityToken: String, userIdentifier: String, email: String?) async throws -> AuthResponse {
        var body: [String: Any] = [
            "identity_token": identityToken,
            "user_identifier": userIdentifier
        ]
        if let email = email {
            body["email"] = email
        }
        return try await post("/auth/apple", body: body)
    }

    // MARK: - Config

    func getConfig() async throws -> ConfigResponse {
        return try await get("/config")
    }

    // MARK: - Servers

    func provisionServer(host: String, port: Int, username: String, password: String, name: String, commands: [NewCommand]?) async throws -> ProvisionResponse {
        var body: [String: Any] = [
            "host": host,
            "port": port,
            "username": username,
            "password": password,
            "name": name
        ]
        if let commands = commands {
            let commandDicts = commands.map { cmd -> [String: Any] in
                var dict: [String: Any] = ["label": cmd.name, "command": cmd.command]
                if let desc = cmd.description {
                    dict["description"] = desc
                }
                return dict
            }
            body["commands"] = commandDicts
        }
        return try await post("/setup/provision", body: body)
    }

    func createServer(name: String, host: String, port: Int, username: String) async throws -> Server {
        let body: [String: Any] = [
            "name": name,
            "host": host,
            "port": port,
            "username": username
        ]
        return try await post("/servers", body: body)
    }

    func deleteServer(id: String) async throws {
        try await delete("/servers/\(id)")
    }

    // MARK: - Commands

    func createCommand(serverId: String, name: String, command: String, description: String?) async throws {
        let body: [String: Any] = [
            "label": name,
            "command": command
        ]
        let _: Command = try await post("/servers/\(serverId)/commands", body: body)
    }

    func deleteCommand(id: String) async throws {
        try await delete("/commands/\(id)")
    }

    // MARK: - Execution

    func executeCommand(serverId: String, commandId: String) async throws -> ExecResponse {
        let body: [String: Any] = [
            "server_id": serverId,
            "command_id": commandId
        ]
        return try await post("/exec", body: body)
    }

    func executeAdhoc(serverId: String, command: String) async throws -> ExecResponse {
        let body: [String: Any] = [
            "server_id": serverId,
            "command": command
        ]
        return try await post("/exec/adhoc", body: body)
    }

    // MARK: - Keys

    func getKeys() async throws -> [SSHKey] {
        let response: KeysResponse = try await get("/keys")
        return response.keys
    }

    func generateKey() async throws -> GenerateKeyResponse {
        return try await post("/keys/generate", body: [:])
    }

    // MARK: - HTTP Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        addAuthHeader(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    @discardableResult
    private func delete(_ path: String) async throws -> Data {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        addAuthHeader(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    private func addAuthHeader(_ request: inout URLRequest) {
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TapError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw TapError.serverError(apiError.error ?? apiError.message ?? "Unknown error")
            }
            throw TapError.httpError(httpResponse.statusCode)
        }
    }
}

enum TapError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .serverError(let message):
            return message
        }
    }
}
