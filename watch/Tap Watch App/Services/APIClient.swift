import Foundation

actor APIClient {
    private let baseURL: String
    private let token: String
    private let session: URLSession

    init(baseURL: String, token: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.token = token
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Config

    func getConfig() async throws -> ConfigResponse {
        return try await get("/config")
    }

    // MARK: - Overview / Metrics

    func getOverview() async throws -> [ServerOverview] {
        let (data, response) = try await request("GET", path: "/overview")
        try validateResponse(response)
        do {
            return try JSONDecoder().decode([ServerOverview].self, from: data)
        } catch {
            let raw = String(data: data, encoding: .utf8) ?? "nil"
            print("[Tap] Overview raw response: \(raw.prefix(500))")
            throw error
        }
    }

    // MARK: - Execution

    func execute(serverId: String, commandId: String) async throws -> ExecResult {
        let body = ExecRequest(serverId: serverId, commandId: commandId)
        return try await post("/exec", body: body)
    }

    // MARK: - Health

    func ping(serverId: String) async throws -> PingResult {
        return try await get("/servers/\(serverId)/ping")
    }

    func healthCheck() async throws -> [String: Any] {
        let (data, _) = try await request("GET", path: "/health")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json ?? [:]
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await request("GET", path: path)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        let bodyData = try JSONEncoder().encode(body)
        let (data, response) = try await request("POST", path: path, body: bodyData)
        try validateResponse(response)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func request(_ method: String, path: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        if let body = body {
            request.httpBody = body
        }

        return try await session.data(for: request)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default: throw APIError.serverError(http.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid relay URL"
        case .invalidResponse: return "Invalid response from relay"
        case .unauthorized: return "Invalid or expired token"
        case .notFound: return "Resource not found"
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}
