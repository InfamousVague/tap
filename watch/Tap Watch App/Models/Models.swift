import Foundation

// MARK: - API Response Models

struct ConfigResponse: Codable {
    let version: String
    let servers: [Server]
}

struct Server: Codable, Identifiable {
    let id: String
    let name: String
    let host: String
    let port: Int
    let user: String
    let status: String?
    let latencyMs: Int?
    let commands: [Command]
    let suites: [Suite]

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, user, status, commands, suites
        case latencyMs = "latency_ms"
    }

    var statusColor: ServerStatus {
        switch status {
        case "up": return .up
        case "down": return .down
        default: return .unknown
        }
    }
}

enum ServerStatus {
    case up, down, unknown

    var label: String {
        switch self {
        case .up: return "Online"
        case .down: return "Offline"
        case .unknown: return "Unknown"
        }
    }
}

struct Command: Codable, Identifiable {
    let id: String
    let serverId: String
    let label: String
    let command: String
    let confirm: Bool
    let timeoutSec: Int
    let sortOrder: Int
    let pinned: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, command, confirm, pinned
        case serverId = "server_id"
        case timeoutSec = "timeout_sec"
        case sortOrder = "sort_order"
    }
}

struct Suite: Codable, Identifiable {
    let id: String
    let serverId: String
    let label: String

    enum CodingKeys: String, CodingKey {
        case id, label
        case serverId = "server_id"
    }
}

struct ExecResult: Codable {
    let status: String
    let exitCode: Int?
    let stdout: String
    let stderr: String
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case status, stdout, stderr
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    var isSuccess: Bool { status == "success" }
    var displayOutput: String { stdout.isEmpty ? stderr : stdout }
}

struct PingResult: Codable {
    let status: String
    let latencyMs: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case latencyMs = "latency_ms"
    }
}

struct ExecRequest: Codable {
    let serverId: String
    let commandId: String

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case commandId = "command_id"
    }
}
