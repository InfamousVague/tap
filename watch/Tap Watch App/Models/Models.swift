import Foundation
import SwiftUI

// MARK: - API Response Models

struct ConfigResponse: Codable {
    let version: String?
    let servers: [Server]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        servers = (try? container.decode([Server].self, forKey: .servers)) ?? []
    }
}

struct Server: Codable, Identifiable {
    let id: String
    let name: String
    let host: String
    let port: Int?
    let user: String?
    let status: ServerStatus
    let latencyMs: Int?
    let commands: [Command]
    let suites: [Suite]

    enum CodingKeys: String, CodingKey {
        case id, name, host, port, user, status, commands, suites
        case latencyMs = "latency_ms"
    }

    // Memberwise init for mock data / programmatic creation
    init(id: String, name: String, host: String, port: Int? = 22, user: String? = "root",
         status: ServerStatus = .unknown, latencyMs: Int? = nil,
         commands: [Command] = [], suites: [Suite] = []) {
        self.id = id; self.name = name; self.host = host; self.port = port
        self.user = user; self.status = status; self.latencyMs = latencyMs
        self.commands = commands; self.suites = suites
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decodeIfPresent(Int.self, forKey: .port)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        status = (try? container.decode(ServerStatus.self, forKey: .status)) ?? .unknown
        latencyMs = try container.decodeIfPresent(Int.self, forKey: .latencyMs)
        commands = (try? container.decode([Command].self, forKey: .commands)) ?? []
        suites = (try? container.decode([Suite].self, forKey: .suites)) ?? []
    }
}

enum ServerStatus: String, Codable {
    case up, down, unknown

    var label: String {
        switch self {
        case .up: return "Online"
        case .down: return "Offline"
        case .unknown: return "Unknown"
        }
    }

    var color: String {
        switch self {
        case .up: return "green"
        case .down: return "red"
        case .unknown: return "gray"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)
        switch raw {
        case "up": self = .up
        case "down": self = .down
        default: self = .unknown
        }
    }
}

struct Command: Codable, Identifiable {
    let id: String
    let serverId: String?
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

    // Memberwise init
    init(id: String, serverId: String? = nil, label: String, command: String,
         confirm: Bool = false, timeoutSec: Int = 30, sortOrder: Int = 0, pinned: Bool = false) {
        self.id = id; self.serverId = serverId; self.label = label; self.command = command
        self.confirm = confirm; self.timeoutSec = timeoutSec; self.sortOrder = sortOrder; self.pinned = pinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        serverId = try container.decodeIfPresent(String.self, forKey: .serverId)
        label = try container.decode(String.self, forKey: .label)
        command = try container.decode(String.self, forKey: .command)
        confirm = (try? container.decode(Bool.self, forKey: .confirm)) ?? false
        timeoutSec = (try? container.decode(Int.self, forKey: .timeoutSec)) ?? 30
        sortOrder = (try? container.decode(Int.self, forKey: .sortOrder)) ?? 0
        pinned = (try? container.decode(Bool.self, forKey: .pinned)) ?? false
    }
}

struct Suite: Codable, Identifiable {
    let id: String
    let serverId: String?
    let label: String

    enum CodingKeys: String, CodingKey {
        case id, label
        case serverId = "server_id"
    }
}

struct ExecResult: Codable {
    let status: String
    let exitCode: Int?
    let stdout: String?
    let stderr: String?
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case status, stdout, stderr
        case exitCode = "exit_code"
        case durationMs = "duration_ms"
    }

    var isSuccess: Bool { status == "success" }
    var displayOutput: String {
        let out = stdout ?? ""
        let err = stderr ?? ""
        return out.isEmpty ? err : out
    }
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

// MARK: - Server Overview (Metrics)

struct ServerOverview: Codable, Identifiable {
    var id: String { serverId }
    let serverId: String
    let serverName: String
    let status: String
    let latencyMs: Int?
    let os: String?
    let kernel: String?
    let uptime: String?
    let load: [Double]?
    let disk: DiskOverview?
    let memory: MemoryOverview?
    let ip: String?
    let dockerRunning: Int?
    let dockerTotal: Int?

    enum CodingKeys: String, CodingKey {
        case serverId = "server_id"
        case serverName = "server_name"
        case status
        case latencyMs = "latency_ms"
        case os, kernel, uptime, load, disk, memory, ip
        case dockerRunning = "docker_running"
        case dockerTotal = "docker_total"
    }

    var isUp: Bool { status == "up" }
    var isDown: Bool { status == "down" }

    var loadStatus: HealthLevel {
        guard let l = load?.first else { return .unknown }
        if l < 1.0 { return .good }
        if l < 2.0 { return .warning }
        return .critical
    }

    var diskStatus: HealthLevel {
        guard let d = disk?.usePercent else { return .unknown }
        if d < 70 { return .good }
        if d < 85 { return .warning }
        return .critical
    }

    var memoryStatus: HealthLevel {
        guard let m = memory?.usePercent else { return .unknown }
        if m < 70 { return .good }
        if m < 85 { return .warning }
        return .critical
    }

    /// Overall health based on worst metric
    var overallHealth: HealthLevel {
        if isDown { return .critical }
        let levels = [loadStatus, diskStatus, memoryStatus].filter { $0 != .unknown }
        if levels.contains(.critical) { return .critical }
        if levels.contains(.warning) { return .warning }
        if levels.isEmpty { return .unknown }
        return .good
    }
}

struct DiskOverview: Codable {
    let total: String
    let used: String
    let available: String
    let usePercent: Int

    enum CodingKeys: String, CodingKey {
        case total, used, available
        case usePercent = "use_percent"
    }
}

struct MemoryOverview: Codable {
    let totalMb: Int
    let usedMb: Int
    let freeMb: Int
    let usePercent: Int

    enum CodingKeys: String, CodingKey {
        case totalMb = "total_mb"
        case usedMb = "used_mb"
        case freeMb = "free_mb"
        case usePercent = "use_percent"
    }
}

enum HealthLevel: Comparable {
    case unknown, good, warning, critical

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .good: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}
