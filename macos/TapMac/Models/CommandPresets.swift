import Foundation

// MARK: - Command Preset System
// Mirrors the relay's template system but lives client-side for instant UI.
// These match the template IDs in relay/src/templates/mod.rs

struct CommandPreset: Identifiable, Hashable {
    let id: String
    let category: PresetCategory
    let name: String
    let command: String
    let icon: String          // SF Symbol name
    let confirm: Bool
    let variables: [PresetVariable]
    let responseTemplate: ResponseTemplate?
}

struct PresetVariable: Hashable {
    let name: String
    let placeholder: String
    let description: String
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

    var color: String {
        switch self {
        case .system: return "blue"
        case .systemd: return "purple"
        case .docker: return "cyan"
        case .nginx: return "green"
        case .database: return "orange"
        case .deploy: return "pink"
        case .network: return "teal"
        }
    }
}

// MARK: - Response Templates
// Defines how to parse and display output from known commands

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

// MARK: - Parsed Output Types

struct ParsedDiskUsage {
    let filesystem: String
    let size: String
    let used: String
    let available: String
    let usePercent: Int
    let mountPoint: String
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
    let users: Int
}

struct ParsedServiceStatus {
    let name: String
    let isActive: Bool
    let subState: String  // "running", "dead", etc.
    let pid: Int?
    let uptime: String?
}

struct ParsedDockerContainer {
    let name: String
    let status: String
    let isRunning: Bool
    let ports: String?
}

struct ParsedDockerStat {
    let name: String
    let cpuPercent: String
    let memUsage: String
}

struct ParsedPM2Process {
    let name: String
    let id: Int
    let status: String
    let cpu: String
    let memory: String
    let uptime: String
}

// MARK: - Output Parser

struct CommandOutputParser {

    static func parse(output: String, template: ResponseTemplate) -> Any? {
        switch template {
        case .diskUsage:
            return parseDiskUsage(output)
        case .memory:
            return parseMemory(output)
        case .cpuLoad:
            return parseCPULoad(output)
        case .uptime:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        case .serviceStatus:
            return parseServiceStatus(output)
        case .serviceLogs:
            return parseServiceLogs(output)
        case .dockerContainers:
            return parseDockerContainers(output)
        case .dockerStats:
            return parseDockerStats(output)
        case .nginxTest:
            return parseNginxTest(output)
        case .postgresReady:
            return output.lowercased().contains("accepting connections")
        case .redisStatus:
            return output.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "PONG"
        case .pm2Status:
            return parsePM2Status(output)
        case .connectionCount:
            return parseConnectionCount(output)
        case .topProcesses:
            return parseTopProcesses(output)
        case .gitCommit:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Disk Usage

    static func parseDiskUsage(_ output: String) -> ParsedDiskUsage? {
        // Expected: /dev/sda1       50G   22G   26G  46% /
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let line = lines.last else { return nil }
        let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard parts.count >= 5 else { return nil }

        let percentStr = parts[4].replacingOccurrences(of: "%", with: "")
        let percent = Int(percentStr) ?? 0

        return ParsedDiskUsage(
            filesystem: parts[0],
            size: parts[1],
            used: parts[2],
            available: parts[3],
            usePercent: percent,
            mountPoint: parts.count > 5 ? parts[5] : "/"
        )
    }

    // MARK: - Memory

    static func parseMemory(_ output: String) -> ParsedMemory? {
        // Expected output from "free -h":
        //               total        used        free      shared  buff/cache   available
        // Mem:          15Gi       4.2Gi       8.1Gi       312Mi       3.4Gi        11Gi
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
        } else if s.hasSuffix("ti") || s.hasSuffix("t") {
            return (Double(s.replacingOccurrences(of: "ti", with: "").replacingOccurrences(of: "t", with: "")) ?? 0) * 1024.0
        }
        return Double(s) ?? 0
    }

    // MARK: - CPU Load

    static func parseCPULoad(_ output: String) -> ParsedCPULoad? {
        // Expected: 12:34:56 up 5 days, 3 users, load average: 0.15, 0.20, 0.18
        let s = output.lowercased()
        guard let loadRange = s.range(of: "load average:") ?? s.range(of: "load averages:") else { return nil }
        let loadStr = s[loadRange.upperBound...].trimmingCharacters(in: .whitespaces)
        let parts = loadStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3 else { return nil }

        let load1 = Double(parts[0]) ?? 0
        let load5 = Double(parts[1]) ?? 0
        let load15 = Double(parts[2]) ?? 0

        // Parse users
        var users = 0
        if let usersMatch = s.range(of: #"\d+ user"#, options: .regularExpression) {
            let numStr = s[usersMatch].split(separator: " ").first ?? ""
            users = Int(numStr) ?? 0
        }

        return ParsedCPULoad(load1: load1, load5: load5, load15: load15, users: users)
    }

    // MARK: - Service Status

    static func parseServiceStatus(_ output: String) -> ParsedServiceStatus? {
        let lines = output.components(separatedBy: "\n")

        // Parse service name from first line: "● nginx.service - A high performance web server"
        var name = "unknown"
        if let first = lines.first {
            let cleaned = first.replacingOccurrences(of: "●", with: "").trimmingCharacters(in: .whitespaces)
            if let dashRange = cleaned.range(of: " - ") {
                name = String(cleaned[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            } else {
                name = cleaned
            }
        }

        // Parse Active line: "Active: active (running) since ..."
        var isActive = false
        var subState = "unknown"
        var uptime: String?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Active:") {
                isActive = trimmed.contains("active")
                // Extract substate from parens
                if let openParen = trimmed.firstIndex(of: "("),
                   let closeParen = trimmed.firstIndex(of: ")") {
                    subState = String(trimmed[trimmed.index(after: openParen)..<closeParen])
                }
                // Extract uptime from "since" or "ago"
                if let sinceRange = trimmed.range(of: "; ") {
                    let timeStr = String(trimmed[sinceRange.upperBound...])
                    uptime = timeStr.replacingOccurrences(of: " ago", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Parse PID
        var pid: Int?
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Main PID:") {
                let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
                if parts.count >= 3, let p = Int(parts[2]) {
                    pid = p
                }
            }
        }

        return ParsedServiceStatus(name: name, isActive: isActive, subState: subState, pid: pid, uptime: uptime)
    }

    // MARK: - Service Logs

    static func parseServiceLogs(_ output: String) -> [(level: String, message: String)] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.map { line in
            let level: String
            let lower = line.lowercased()
            if lower.contains("error") || lower.contains("fatal") || lower.contains("panic") {
                level = "error"
            } else if lower.contains("warn") {
                level = "warning"
            } else if lower.contains("info") {
                level = "info"
            } else {
                level = "debug"
            }
            return (level: level, message: line)
        }
    }

    // MARK: - Docker

    static func parseDockerContainers(_ output: String) -> [ParsedDockerContainer] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Skip header line
        let dataLines = lines.count > 1 ? Array(lines.dropFirst()) : lines
        return dataLines.compactMap { line in
            let parts = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { return nil }
            return ParsedDockerContainer(
                name: parts[0],
                status: parts[1],
                isRunning: parts[1].lowercased().contains("up"),
                ports: parts.count > 2 ? parts[2] : nil
            )
        }
    }

    static func parseDockerStats(_ output: String) -> [ParsedDockerStat] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        let dataLines = lines.count > 1 ? Array(lines.dropFirst()) : lines
        return dataLines.compactMap { line in
            let parts = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3 else { return nil }
            return ParsedDockerStat(name: parts[0], cpuPercent: parts[1], memUsage: parts[2])
        }
    }

    // MARK: - Nginx

    static func parseNginxTest(_ output: String) -> Bool {
        let combined = output.lowercased()
        return combined.contains("test is successful") || combined.contains("syntax is ok")
    }

    // MARK: - PM2

    static func parsePM2Status(_ output: String) -> [ParsedPM2Process] {
        // PM2 outputs a table with │ separators
        let lines = output.components(separatedBy: "\n").filter { $0.contains("│") }
        return lines.compactMap { line in
            let cells = line.split(separator: "│").map { $0.trimmingCharacters(in: .whitespaces) }
            // Typical: │ name │ id │ mode │ status │ cpu │ memory │
            guard cells.count >= 6,
                  let id = Int(cells[1]),
                  !cells[0].lowercased().contains("name") else { return nil }
            return ParsedPM2Process(
                name: cells[0],
                id: id,
                status: cells.count > 3 ? cells[3] : "unknown",
                cpu: cells.count > 4 ? cells[4] : "0%",
                memory: cells.count > 5 ? cells[5] : "0mb",
                uptime: cells.count > 6 ? cells[6] : ""
            )
        }
    }

    // MARK: - Network

    static func parseConnectionCount(_ output: String) -> [String: Int] {
        // ss -s output:
        // Total: 156
        // TCP:   52 (estab 23, closed 12, orphaned 0, timewait 12)
        var result: [String: Int] = [:]
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.lowercased().hasPrefix("total:") {
                let num = line.split(whereSeparator: { $0.isWhitespace }).last.flatMap { Int($0) }
                result["total"] = num ?? 0
            }
            if line.lowercased().hasPrefix("tcp:") {
                if let estabMatch = line.range(of: #"estab \d+"#, options: .regularExpression) {
                    let num = line[estabMatch].split(separator: " ").last.flatMap { Int($0) }
                    result["established"] = num ?? 0
                }
                if let twMatch = line.range(of: #"timewait \d+"#, options: .regularExpression) {
                    let num = line[twMatch].split(separator: " ").last.flatMap { Int($0) }
                    result["timewait"] = num ?? 0
                }
            }
        }
        return result
    }

    // MARK: - Top Processes

    static func parseTopProcesses(_ output: String) -> [(user: String, pid: String, cpu: String, mem: String, command: String)] {
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        let dataLines = lines.count > 1 ? Array(lines.dropFirst()) : lines
        return dataLines.prefix(10).compactMap { line in
            let parts = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard parts.count >= 11 else { return nil }
            return (user: parts[0], pid: parts[1], cpu: parts[2], mem: parts[3], command: parts.last ?? "")
        }
    }
}

// MARK: - All Presets

extension CommandPreset {
    static let all: [CommandPreset] = [
        // System
        CommandPreset(
            id: "sys-disk", category: .system, name: "Disk Usage",
            command: "df -h / | tail -1", icon: "internaldrive",
            confirm: false, variables: [],
            responseTemplate: .diskUsage
        ),
        CommandPreset(
            id: "sys-memory", category: .system, name: "Memory Usage",
            command: "free -h | head -2", icon: "memorychip",
            confirm: false, variables: [],
            responseTemplate: .memory
        ),
        CommandPreset(
            id: "sys-cpu", category: .system, name: "CPU Load",
            command: "uptime", icon: "cpu",
            confirm: false, variables: [],
            responseTemplate: .cpuLoad
        ),
        CommandPreset(
            id: "sys-procs", category: .system, name: "Top Processes",
            command: "ps aux --sort=-%mem | head -20", icon: "list.bullet.rectangle",
            confirm: false, variables: [],
            responseTemplate: .topProcesses
        ),
        CommandPreset(
            id: "sys-uptime", category: .system, name: "Uptime",
            command: "uptime -p", icon: "clock.arrow.circlepath",
            confirm: false, variables: [],
            responseTemplate: .uptime
        ),

        // Systemd
        CommandPreset(
            id: "svc-restart", category: .systemd, name: "Restart Service",
            command: "systemctl restart {{service}}", icon: "arrow.clockwise.circle",
            confirm: true,
            variables: [PresetVariable(name: "service", placeholder: "nginx", description: "Service name")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "svc-stop", category: .systemd, name: "Stop Service",
            command: "systemctl stop {{service}}", icon: "stop.circle",
            confirm: true,
            variables: [PresetVariable(name: "service", placeholder: "nginx", description: "Service name")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "svc-status", category: .systemd, name: "Service Status",
            command: "systemctl status {{service}} --no-pager", icon: "stethoscope",
            confirm: false,
            variables: [PresetVariable(name: "service", placeholder: "nginx", description: "Service name")],
            responseTemplate: .serviceStatus
        ),
        CommandPreset(
            id: "svc-logs", category: .systemd, name: "Service Logs",
            command: "journalctl -u {{service}} -n 30 --no-pager", icon: "doc.text",
            confirm: false,
            variables: [PresetVariable(name: "service", placeholder: "nginx", description: "Service name")],
            responseTemplate: .serviceLogs
        ),

        // Docker
        CommandPreset(
            id: "docker-ps", category: .docker, name: "List Containers",
            command: "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'",
            icon: "shippingbox",
            confirm: false, variables: [],
            responseTemplate: .dockerContainers
        ),
        CommandPreset(
            id: "docker-restart", category: .docker, name: "Restart Container",
            command: "docker restart {{container}}", icon: "arrow.clockwise",
            confirm: true,
            variables: [PresetVariable(name: "container", placeholder: "my-app", description: "Container name")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "docker-logs", category: .docker, name: "Container Logs",
            command: "docker logs --tail 30 {{container}}", icon: "doc.text",
            confirm: false,
            variables: [PresetVariable(name: "container", placeholder: "my-app", description: "Container name")],
            responseTemplate: .serviceLogs
        ),
        CommandPreset(
            id: "docker-stats", category: .docker, name: "Docker Stats",
            command: "docker stats --no-stream --format 'table {{.Name}}\\t{{.CPUPerc}}\\t{{.MemUsage}}'",
            icon: "chart.bar",
            confirm: false, variables: [],
            responseTemplate: .dockerStats
        ),

        // Nginx
        CommandPreset(
            id: "nginx-test", category: .nginx, name: "Test Config",
            command: "nginx -t", icon: "checkmark.seal",
            confirm: false, variables: [],
            responseTemplate: .nginxTest
        ),
        CommandPreset(
            id: "nginx-reload", category: .nginx, name: "Reload Nginx",
            command: "systemctl reload nginx", icon: "arrow.clockwise",
            confirm: true, variables: [],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "nginx-access", category: .nginx, name: "Access Log",
            command: "tail -20 /var/log/nginx/access.log", icon: "person.2",
            confirm: false, variables: [],
            responseTemplate: .serviceLogs
        ),
        CommandPreset(
            id: "nginx-error", category: .nginx, name: "Error Log",
            command: "tail -20 /var/log/nginx/error.log", icon: "exclamationmark.triangle",
            confirm: false, variables: [],
            responseTemplate: .serviceLogs
        ),

        // Database
        CommandPreset(
            id: "pg-ready", category: .database, name: "PostgreSQL Status",
            command: "pg_isready", icon: "cylinder",
            confirm: false, variables: [],
            responseTemplate: .postgresReady
        ),
        CommandPreset(
            id: "redis-ping", category: .database, name: "Redis Ping",
            command: "redis-cli ping", icon: "bolt.horizontal",
            confirm: false, variables: [],
            responseTemplate: .redisStatus
        ),
        CommandPreset(
            id: "mysql-status", category: .database, name: "MySQL Status",
            command: "mysqladmin status", icon: "cylinder.split.1x2",
            confirm: false, variables: [],
            responseTemplate: nil
        ),

        // Deploy
        CommandPreset(
            id: "git-pull", category: .deploy, name: "Git Pull",
            command: "cd {{path}} && git pull", icon: "arrow.down.circle",
            confirm: true,
            variables: [PresetVariable(name: "path", placeholder: "/var/www/app", description: "Project path")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "git-commit", category: .deploy, name: "Current Commit",
            command: "cd {{path}} && git log --oneline -1", icon: "number",
            confirm: false,
            variables: [PresetVariable(name: "path", placeholder: "/var/www/app", description: "Project path")],
            responseTemplate: .gitCommit
        ),
        CommandPreset(
            id: "pm2-restart", category: .deploy, name: "PM2 Restart",
            command: "pm2 restart {{app}}", icon: "arrow.clockwise",
            confirm: true,
            variables: [PresetVariable(name: "app", placeholder: "my-app", description: "PM2 app name")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "pm2-status", category: .deploy, name: "PM2 Status",
            command: "pm2 status", icon: "chart.bar",
            confirm: false, variables: [],
            responseTemplate: .pm2Status
        ),

        // Network
        CommandPreset(
            id: "net-port", category: .network, name: "Check Port",
            command: "ss -tlnp | grep {{port}}", icon: "antenna.radiowaves.left.and.right",
            confirm: false,
            variables: [PresetVariable(name: "port", placeholder: "3000", description: "Port number")],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "net-connections", category: .network, name: "Connection Count",
            command: "ss -s", icon: "arrow.left.arrow.right",
            confirm: false, variables: [],
            responseTemplate: .connectionCount
        ),
        CommandPreset(
            id: "net-dns", category: .network, name: "DNS Lookup",
            command: "dig {{domain}} +short", icon: "magnifyingglass",
            confirm: false,
            variables: [PresetVariable(name: "domain", placeholder: "example.com", description: "Domain name")],
            responseTemplate: nil
        ),

        // Bonus common ones
        CommandPreset(
            id: "sys-reboot", category: .system, name: "Reboot Server",
            command: "sudo reboot", icon: "power",
            confirm: true, variables: [],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "sys-shutdown", category: .system, name: "Shutdown Server",
            command: "sudo shutdown -h now", icon: "power.circle",
            confirm: true, variables: [],
            responseTemplate: nil
        ),
        CommandPreset(
            id: "sys-updates", category: .system, name: "Check Updates",
            command: "apt list --upgradable 2>/dev/null | tail -20 || yum check-update 2>/dev/null | tail -20",
            icon: "arrow.down.to.line",
            confirm: false, variables: [],
            responseTemplate: nil
        ),
    ]

    static func byCategory() -> [(category: PresetCategory, presets: [CommandPreset])] {
        PresetCategory.allCases.compactMap { category in
            let presets = all.filter { $0.category == category }
            return presets.isEmpty ? nil : (category: category, presets: presets)
        }
    }

    /// Quick presets shown during server setup — the most universally useful ones
    static let suggestedForNewServer: [CommandPreset] = [
        all.first(where: { $0.id == "sys-disk" })!,
        all.first(where: { $0.id == "sys-memory" })!,
        all.first(where: { $0.id == "sys-cpu" })!,
        all.first(where: { $0.id == "sys-uptime" })!,
        all.first(where: { $0.id == "sys-reboot" })!,
        all.first(where: { $0.id == "docker-ps" })!,
        all.first(where: { $0.id == "svc-status" })!,
        all.first(where: { $0.id == "net-connections" })!,
    ]

    /// Look up the response template for a given command string
    static func templateForCommand(_ commandStr: String) -> ResponseTemplate? {
        // Exact match first
        if let preset = all.first(where: { $0.command == commandStr }) {
            return preset.responseTemplate
        }
        // Pattern match — handle variable substitutions
        let normalized = commandStr.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("df -h") { return .diskUsage }
        if normalized.hasPrefix("free -h") || normalized.hasPrefix("free -m") { return .memory }
        if normalized == "uptime" || normalized == "uptime -p" { return .uptime }
        if normalized.hasPrefix("systemctl status") { return .serviceStatus }
        if normalized.hasPrefix("journalctl") { return .serviceLogs }
        if normalized.hasPrefix("docker ps") { return .dockerContainers }
        if normalized.hasPrefix("docker stats") { return .dockerStats }
        if normalized == "nginx -t" { return .nginxTest }
        if normalized == "pg_isready" { return .postgresReady }
        if normalized == "redis-cli ping" { return .redisStatus }
        if normalized == "pm2 status" { return .pm2Status }
        if normalized == "ss -s" { return .connectionCount }
        if normalized.hasPrefix("ps aux") { return .topProcesses }
        if normalized.contains("git log --oneline") { return .gitCommit }
        if normalized.contains("tail") && normalized.contains("log") { return .serviceLogs }
        return nil
    }
}
