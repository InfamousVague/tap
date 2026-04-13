import Foundation

// MARK: - Command Preset System (Watch)

struct CommandPreset: Identifiable, Hashable {
    let id: String
    let category: PresetCategory
    let name: String
    let command: String
    let icon: String
    let confirm: Bool
    let responseTemplate: ResponseTemplate?
}

enum PresetCategory: String, CaseIterable, Identifiable {
    case system = "System"
    case systemd = "Systemd"
    case docker = "Docker"
    case nginx = "Nginx"
    case database = "Database"
    case deploy = "Deploy"
    case network = "Network"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "cpu"
        case .systemd: return "gearshape.2"
        case .docker: return "shippingbox"
        case .nginx: return "globe"
        case .database: return "cylinder"
        case .deploy: return "arrow.triangle.branch"
        case .network: return "network"
        }
    }
}

// MARK: - Response Templates

enum ResponseTemplate: Hashable {
    case diskUsage
    case memory
    case cpuLoad
    case uptime
    case serviceStatus
    case serviceLogs
    case dockerContainers
    case dockerStats
    case nginxTest
    case postgresReady
    case redisStatus
    case pm2Status
    case connectionCount
    case topProcesses
    case gitCommit
}

// MARK: - Parsed Output (type-safe enum)

enum ParsedOutput {
    case disk(ParsedDiskUsage)
    case memory(ParsedMemory)
    case cpu(ParsedCPULoad)
    case uptimeString(String)
    case service(ParsedServiceStatus)
    case logs(ParsedLogSummary)
    case dockerContainers([ParsedDockerContainer])
    case boolResult(Bool)          // nginx test, pg_isready, redis ping
    case connections(ParsedConnections)
    case commitString(String)
}

struct ParsedDiskUsage {
    let size: String
    let used: String
    let available: String
    let usePercent: Int
}

struct ParsedMemory {
    let totalGB: Double
    let usedGB: Double
    let freeGB: Double
    let usePercent: Int
}

struct ParsedCPULoad {
    let load1: Double
    let load5: Double
    let load15: Double
}

struct ParsedServiceStatus {
    let name: String
    let isActive: Bool
    let subState: String
    let uptime: String?
}

struct ParsedDockerContainer {
    let name: String
    let status: String
    let isRunning: Bool
}

struct ParsedLogEntry {
    let level: String   // "error", "warning", "info"
    let message: String
}

struct ParsedLogSummary {
    let entries: [ParsedLogEntry]
    var errorCount: Int { entries.filter { $0.level == "error" }.count }
    var warningCount: Int { entries.filter { $0.level == "warning" }.count }
}

struct ParsedConnections {
    let total: Int?
    let established: Int?
    let timewait: Int?
}

// MARK: - Output Parser

struct CommandOutputParser {

    static func parse(output: String, template: ResponseTemplate) -> ParsedOutput? {
        switch template {
        case .diskUsage:
            guard let d = parseDiskUsage(output) else { return nil }
            return .disk(d)
        case .memory:
            guard let m = parseMemory(output) else { return nil }
            return .memory(m)
        case .cpuLoad:
            guard let c = parseCPULoad(output) else { return nil }
            return .cpu(c)
        case .uptime:
            let s = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : .uptimeString(s)
        case .serviceStatus:
            guard let svc = parseServiceStatus(output) else { return nil }
            return .service(svc)
        case .serviceLogs:
            let logs = parseLogLines(output)
            return logs.isEmpty ? nil : .logs(ParsedLogSummary(entries: logs))
        case .dockerContainers:
            let containers = parseDockerContainers(output)
            return containers.isEmpty ? nil : .dockerContainers(containers)
        case .nginxTest:
            let ok = output.lowercased().contains("test is successful") || output.lowercased().contains("syntax is ok")
            return .boolResult(ok)
        case .postgresReady:
            return .boolResult(output.lowercased().contains("accepting connections"))
        case .redisStatus:
            return .boolResult(output.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "PONG")
        case .connectionCount:
            let c = parseConnectionCount(output)
            return .connections(c)
        case .gitCommit:
            let s = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : .commitString(s)
        case .dockerStats, .pm2Status, .topProcesses:
            return nil
        }
    }

    // MARK: - Disk Usage

    static func parseDiskUsage(_ output: String) -> ParsedDiskUsage? {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let line = lines.last else { return nil }
        let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 5 else { return nil }
        let percentStr = parts[4].replacingOccurrences(of: "%", with: "")
        return ParsedDiskUsage(
            size: parts[1], used: parts[2], available: parts[3],
            usePercent: Int(percentStr) ?? 0
        )
    }

    // MARK: - Memory

    static func parseMemory(_ output: String) -> ParsedMemory? {
        let lines = output.components(separatedBy: "\n")
        guard let memLine = lines.first(where: { $0.lowercased().hasPrefix("mem:") }) else { return nil }
        let parts = memLine.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 4 else { return nil }

        let total = parseMemValue(parts[1])
        let used = parseMemValue(parts[2])
        let free = parseMemValue(parts[3])
        let percent = total > 0 ? Int((used / total) * 100) : 0
        return ParsedMemory(totalGB: total, usedGB: used, freeGB: free, usePercent: percent)
    }

    private static func parseMemValue(_ str: String) -> Double {
        let s = str.lowercased()
        if s.hasSuffix("gi") || s.hasSuffix("g") {
            return Double(s.replacingOccurrences(of: "gi", with: "").replacingOccurrences(of: "g", with: "")) ?? 0
        } else if s.hasSuffix("mi") || s.hasSuffix("m") {
            return (Double(s.replacingOccurrences(of: "mi", with: "").replacingOccurrences(of: "m", with: "")) ?? 0) / 1024.0
        }
        return Double(s) ?? 0
    }

    // MARK: - CPU Load

    static func parseCPULoad(_ output: String) -> ParsedCPULoad? {
        let s = output.lowercased()
        guard let loadRange = s.range(of: "load average:") ?? s.range(of: "load averages:") else { return nil }
        let loadStr = s[loadRange.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = loadStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3 else { return nil }
        return ParsedCPULoad(
            load1: Double(parts[0]) ?? 0,
            load5: Double(parts[1]) ?? 0,
            load15: Double(parts[2]) ?? 0
        )
    }

    // MARK: - Service Status

    static func parseServiceStatus(_ output: String) -> ParsedServiceStatus? {
        let lines = output.components(separatedBy: "\n")
        var name = "unknown"
        if let first = lines.first {
            let cleaned = first.replacingOccurrences(of: "●", with: "").trimmingCharacters(in: .whitespaces)
            if let dashRange = cleaned.range(of: " - ") {
                name = String(cleaned[..<dashRange.lowerBound])
            }
        }

        var isActive = false
        var subState = "unknown"
        var uptime: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Active:") {
                isActive = trimmed.contains("active")
                if let open = trimmed.firstIndex(of: "("), let close = trimmed.firstIndex(of: ")") {
                    subState = String(trimmed[trimmed.index(after: open)..<close])
                }
                if let sinceRange = trimmed.range(of: "; ") {
                    uptime = String(trimmed[sinceRange.upperBound...])
                        .replacingOccurrences(of: " ago", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return ParsedServiceStatus(name: name, isActive: isActive, subState: subState, uptime: uptime)
    }

    // MARK: - Logs

    static func parseLogLines(_ output: String) -> [ParsedLogEntry] {
        output.components(separatedBy: "\n").filter { !$0.isEmpty }.map { line in
            let lower = line.lowercased()
            let level: String
            if lower.contains("error") || lower.contains("fatal") { level = "error" }
            else if lower.contains("warn") { level = "warning" }
            else { level = "info" }
            return ParsedLogEntry(level: level, message: line)
        }
    }

    // MARK: - Docker

    static func parseDockerContainers(_ output: String) -> [ParsedDockerContainer] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        let dataLines = lines.count > 1 ? Array(lines.dropFirst()) : lines
        return dataLines.compactMap { line in
            let parts = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { return nil }
            return ParsedDockerContainer(
                name: parts[0], status: parts[1],
                isRunning: parts[1].lowercased().contains("up")
            )
        }
    }

    // MARK: - Network

    static func parseConnectionCount(_ output: String) -> ParsedConnections {
        var total: Int?
        var established: Int?
        var timewait: Int?
        for line in output.components(separatedBy: "\n") {
            if line.lowercased().hasPrefix("total:") {
                total = line.split(whereSeparator: { $0.isWhitespace }).last.flatMap { Int($0) }
            }
            if line.lowercased().hasPrefix("tcp:") {
                if let range = line.range(of: #"estab \d+"#, options: .regularExpression) {
                    established = line[range].split(separator: " ").last.flatMap { Int($0) }
                }
                if let range = line.range(of: #"timewait \d+"#, options: .regularExpression) {
                    timewait = line[range].split(separator: " ").last.flatMap { Int($0) }
                }
            }
        }
        return ParsedConnections(total: total, established: established, timewait: timewait)
    }
}

// MARK: - Preset Definitions

extension CommandPreset {
    static let all: [CommandPreset] = [
        // System
        CommandPreset(id: "sys-disk", category: .system, name: "Disk Usage", command: "df -h / | tail -1", icon: "internaldrive", confirm: false, responseTemplate: .diskUsage),
        CommandPreset(id: "sys-memory", category: .system, name: "Memory Usage", command: "free -h | head -2", icon: "memorychip", confirm: false, responseTemplate: .memory),
        CommandPreset(id: "sys-cpu", category: .system, name: "CPU Load", command: "uptime", icon: "cpu", confirm: false, responseTemplate: .cpuLoad),
        CommandPreset(id: "sys-uptime", category: .system, name: "Uptime", command: "uptime -p", icon: "clock.arrow.circlepath", confirm: false, responseTemplate: .uptime),
        CommandPreset(id: "sys-reboot", category: .system, name: "Reboot", command: "sudo reboot", icon: "power", confirm: true, responseTemplate: nil),
        // Systemd
        CommandPreset(id: "svc-status", category: .systemd, name: "Service Status", command: "systemctl status {{service}} --no-pager", icon: "stethoscope", confirm: false, responseTemplate: .serviceStatus),
        CommandPreset(id: "svc-restart", category: .systemd, name: "Restart Service", command: "systemctl restart {{service}}", icon: "arrow.clockwise.circle", confirm: true, responseTemplate: nil),
        // Docker
        CommandPreset(id: "docker-ps", category: .docker, name: "List Containers", command: "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'", icon: "shippingbox", confirm: false, responseTemplate: .dockerContainers),
        CommandPreset(id: "docker-restart", category: .docker, name: "Restart Container", command: "docker restart {{container}}", icon: "arrow.clockwise", confirm: true, responseTemplate: nil),
        // Nginx
        CommandPreset(id: "nginx-test", category: .nginx, name: "Test Config", command: "nginx -t", icon: "checkmark.seal", confirm: false, responseTemplate: .nginxTest),
        CommandPreset(id: "nginx-reload", category: .nginx, name: "Reload Nginx", command: "systemctl reload nginx", icon: "arrow.clockwise", confirm: true, responseTemplate: nil),
        // Database
        CommandPreset(id: "pg-ready", category: .database, name: "PostgreSQL Status", command: "pg_isready", icon: "cylinder", confirm: false, responseTemplate: .postgresReady),
        CommandPreset(id: "redis-ping", category: .database, name: "Redis Ping", command: "redis-cli ping", icon: "bolt.horizontal", confirm: false, responseTemplate: .redisStatus),
        // Network
        CommandPreset(id: "net-connections", category: .network, name: "Connections", command: "ss -s", icon: "arrow.left.arrow.right", confirm: false, responseTemplate: .connectionCount),
    ]

    /// Look up the response template for a given command string
    static func templateForCommand(_ commandStr: String) -> ResponseTemplate? {
        if let preset = all.first(where: { $0.command == commandStr }) {
            return preset.responseTemplate
        }
        let normalized = commandStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("df -h") { return .diskUsage }
        if normalized.hasPrefix("free -h") || normalized.hasPrefix("free -m") { return .memory }
        if normalized == "uptime" || normalized == "uptime -p" { return .uptime }
        if normalized.hasPrefix("uptime") { return .cpuLoad }
        if normalized.hasPrefix("systemctl status") { return .serviceStatus }
        if normalized.hasPrefix("journalctl") { return .serviceLogs }
        if normalized.hasPrefix("docker ps") { return .dockerContainers }
        if normalized.hasPrefix("docker stats") { return .dockerStats }
        if normalized == "nginx -t" { return .nginxTest }
        if normalized.hasPrefix("nginx -t") { return .nginxTest }
        if normalized == "pg_isready" { return .postgresReady }
        if normalized == "redis-cli ping" { return .redisStatus }
        if normalized == "pm2 status" { return .pm2Status }
        if normalized == "ss -s" { return .connectionCount }
        if normalized.hasPrefix("ss -") { return .connectionCount }
        if normalized.contains("tail") && normalized.contains("log") { return .serviceLogs }
        if normalized.contains("git log") { return .gitCommit }
        return nil
    }
}
