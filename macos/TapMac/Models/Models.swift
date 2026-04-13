import Foundation

struct Server: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let port: Int?
    let user: String?
    let status: String?
    let latencyMs: Int?
    let commands: [Command]?

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, user, status, commands
        case latencyMs = "latency_ms"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Server, rhs: Server) -> Bool {
        lhs.id == rhs.id
    }

    var commandCount: Int {
        commands?.count ?? 0
    }

    var displayStatus: String {
        status ?? "unknown"
    }
}

struct Command: Codable, Identifiable, Hashable {
    let id: String
    let serverId: String?
    let label: String
    let command: String
    let confirm: Bool?
    let timeoutSec: Int?
    let sortOrder: Int?
    let pinned: Bool?

    enum CodingKeys: String, CodingKey {
        case id, label, command, confirm, pinned
        case serverId = "server_id"
        case timeoutSec = "timeout_sec"
        case sortOrder = "sort_order"
    }

    // Display name for UI
    var displayName: String { label }
}

struct ConfigResponse: Codable {
    let servers: [Server]
}

struct AuthResponse: Codable {
    let token: String
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case token
        case userId = "user_id"
    }
}

struct ProvisionRequest: Codable {
    let host: String
    let port: Int
    let username: String
    let password: String
    let name: String
    let commands: [NewCommand]?
}

struct NewCommand: Codable {
    let name: String
    let command: String
    let description: String?
}

struct ExecRequest: Codable {
    let serverId: String
    let commandId: String

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case commandId = "command_id"
    }
}

struct AdhocExecRequest: Codable {
    let serverId: String
    let command: String

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case command
    }
}

struct ExecResponse: Codable {
    let stdout: String?
    let stderr: String?
    let exitCode: Int?
    let duration: Double?

    enum CodingKeys: String, CodingKey {
        case stdout, stderr, duration
        case exitCode = "exit_code"
    }
}

struct ProvisionResponse: Codable {
    let serverId: String?
    let commandsCreated: Int?
    let connectionVerified: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case commandsCreated = "commands_created"
        case connectionVerified = "connection_verified"
        case error
    }
}

struct CreateServerRequest: Codable {
    let name: String
    let host: String
    let port: Int
    let username: String
}

struct CreateCommandRequest: Codable {
    let name: String
    let command: String
    let description: String?
}

struct SSHKey: Codable, Identifiable {
    let id: String
    let publicKey: String?
    let fingerprint: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, fingerprint
        case publicKey = "public_key"
        case createdAt = "created_at"
    }
}

struct KeysResponse: Codable {
    let keys: [SSHKey]
}

struct GenerateKeyResponse: Codable {
    let key: SSHKey?
    let publicKey: String?

    enum CodingKeys: String, CodingKey {
        case key
        case publicKey = "public_key"
    }
}

struct APIError: Codable {
    let error: String?
    let message: String?
}
