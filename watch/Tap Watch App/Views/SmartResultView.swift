import SwiftUI

/// Renders command output using smart templates when available,
/// falling back to raw text output for unknown commands.
struct SmartResultView: View {
    let result: ExecResult
    let command: Command

    private var parsed: ParsedOutput? {
        guard let template = CommandPreset.templateForCommand(command.command),
              let output = result.stdout ?? result.stderr else { return nil }
        return CommandOutputParser.parse(output: output, template: template)
    }

    var body: some View {
        if let parsed = parsed {
            parsedView(parsed)
        } else {
            rawOutputView
        }
    }

    // MARK: - Parsed Output Router

    @ViewBuilder
    private func parsedView(_ output: ParsedOutput) -> some View {
        switch output {
        case .disk(let disk):
            DiskUsageCard(disk: disk)
        case .memory(let mem):
            MemoryCard(memory: mem)
        case .cpu(let cpu):
            CPULoadCard(cpu: cpu)
        case .uptimeString(let str):
            UptimeCard(uptime: str)
        case .service(let svc):
            ServiceStatusCard(service: svc)
        case .logs(let summary):
            LogsCard(summary: summary)
        case .dockerContainers(let containers):
            DockerContainersCard(containers: containers)
        case .boolResult(let ok):
            BoolResultCard(passed: ok, command: command)
        case .connections(let conn):
            ConnectionCountCard(connections: conn)
        case .commitString(let str):
            GitCommitCard(commit: str)
        }
    }

    // MARK: - Fallback Raw Output

    private var rawOutputView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !result.displayOutput.isEmpty {
                Text("Output")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(truncated(result.displayOutput, lines: 15))
                    .font(.system(.caption2, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
            }
        }
    }

    private func truncated(_ text: String, lines: Int) -> String {
        let allLines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        if allLines.count > lines {
            return "…\n" + allLines.suffix(lines).joined(separator: "\n")
        }
        return allLines.joined(separator: "\n")
    }
}

// MARK: - Disk Usage Card

struct DiskUsageCard: View {
    let disk: ParsedDiskUsage

    var body: some View {
        VStack(spacing: 10) {
            Gauge(value: Double(disk.usePercent), in: 0...100) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 6))
            } currentValueLabel: {
                Text("\(disk.usePercent)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient(percent: disk.usePercent))
            .scaleEffect(1.8)
            .frame(height: 100)

            HStack(spacing: 14) {
                StatMini(label: "Used", value: disk.used, color: .amber)
                StatMini(label: "Free", value: disk.available, color: .green)
                StatMini(label: "Total", value: disk.size, color: .secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Memory Card

struct MemoryCard: View {
    let memory: ParsedMemory

    var body: some View {
        VStack(spacing: 10) {
            Gauge(value: Double(memory.usePercent), in: 0...100) {
                Image(systemName: "memorychip")
                    .font(.system(size: 6))
            } currentValueLabel: {
                Text("\(memory.usePercent)%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(gaugeGradient(percent: memory.usePercent))
            .scaleEffect(1.8)
            .frame(height: 100)

            HStack(spacing: 14) {
                StatMini(label: "Used", value: String(format: "%.1fG", memory.usedGB), color: .amber)
                StatMini(label: "Free", value: String(format: "%.1fG", memory.freeGB), color: .green)
                StatMini(label: "Total", value: String(format: "%.1fG", memory.totalGB), color: .secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - CPU Load Card

struct CPULoadCard: View {
    let cpu: ParsedCPULoad

    var body: some View {
        VStack(spacing: 10) {
            Gauge(value: min(cpu.load1, 4.0), in: 0...4.0) {
                Image(systemName: "cpu")
                    .font(.system(size: 6))
            } currentValueLabel: {
                Text(String(format: "%.2f", cpu.load1))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [.green, .amber, .red]))
            .scaleEffect(1.8)
            .frame(height: 100)

            HStack(spacing: 14) {
                StatMini(label: "1m", value: String(format: "%.2f", cpu.load1), color: loadColor(cpu.load1))
                StatMini(label: "5m", value: String(format: "%.2f", cpu.load5), color: loadColor(cpu.load5))
                StatMini(label: "15m", value: String(format: "%.2f", cpu.load15), color: loadColor(cpu.load15))
            }
        }
        .padding(.vertical, 6)
    }

    private func loadColor(_ v: Double) -> Color {
        if v < 1.0 { return .green }
        if v < 2.0 { return .amber }
        return .red
    }
}

// MARK: - Uptime Card

struct UptimeCard: View {
    let uptime: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.green)
                .shadow(color: .green.opacity(0.5), radius: 8)

            Text(uptime)
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Service Status Card

struct ServiceStatusCard: View {
    let service: ParsedServiceStatus

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: service.isActive ? "checkmark.shield.fill" : "xmark.shield.fill")
                .font(.system(size: 36))
                .foregroundStyle(service.isActive ? .green : .red)
                .shadow(color: (service.isActive ? Color.green : Color.red).opacity(0.5), radius: 8)

            VStack(spacing: 3) {
                Text(service.name)
                    .font(.caption)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Circle()
                        .fill(service.isActive ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(service.subState)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(service.isActive ? .green : .red)
                }

                if let uptime = service.uptime {
                    Text(uptime)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Docker Containers Card

struct DockerContainersCard: View {
    let containers: [ParsedDockerContainer]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(containers.prefix(5).enumerated()), id: \.offset) { _, container in
                HStack(spacing: 6) {
                    Circle()
                        .fill(container.isRunning ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(container.name)
                        .font(.system(.caption2, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    Text(container.isRunning ? "Up" : "Down")
                        .font(.system(.caption2))
                        .foregroundStyle(container.isRunning ? .green : .red)
                }
            }
            if containers.count > 5 {
                Text("+\(containers.count - 5) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bool Result Card (nginx test, pg_isready, redis ping)

struct BoolResultCard: View {
    let passed: Bool
    let command: Command

    private var label: String {
        let cmd = command.command.lowercased()
        if cmd.contains("nginx") {
            return passed ? "Config OK" : "Config Error"
        } else if cmd.contains("pg_isready") || cmd.contains("postgres") {
            return passed ? "PostgreSQL Ready" : "PostgreSQL Down"
        } else if cmd.contains("redis") {
            return passed ? "Redis PONG" : "Redis No Response"
        }
        return passed ? "OK" : "Failed"
    }

    private var icon: String {
        let cmd = command.command.lowercased()
        if cmd.contains("nginx") {
            return passed ? "checkmark.seal.fill" : "xmark.seal.fill"
        } else if cmd.contains("pg_isready") || cmd.contains("postgres") || cmd.contains("redis") || cmd.contains("mysql") {
            return passed ? "cylinder.fill" : "cylinder"
        }
        return passed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(passed ? .green : .red)
                .shadow(color: (passed ? Color.green : Color.red).opacity(0.5), radius: 10)

            Text(label)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(passed ? .green : .red)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Connection Count Card

struct ConnectionCountCard: View {
    let connections: ParsedConnections

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 30))
                .foregroundStyle(.amber)
                .shadow(color: .amber.opacity(0.4), radius: 6)

            HStack(spacing: 14) {
                if let total = connections.total {
                    StatMini(label: "Total", value: "\(total)", color: .amber)
                }
                if let estab = connections.established {
                    StatMini(label: "Estab", value: "\(estab)", color: .green)
                }
                if let tw = connections.timewait {
                    StatMini(label: "TW", value: "\(tw)", color: .secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Logs Card

struct LogsCard: View {
    let summary: ParsedLogSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Error/warning count summary
            if summary.errorCount > 0 || summary.warningCount > 0 {
                HStack(spacing: 8) {
                    if summary.errorCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                            Text("\(summary.errorCount)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    }
                    if summary.warningCount > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("\(summary.warningCount)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Text("\(summary.entries.count) lines")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

            // Last few lines
            ForEach(Array(summary.entries.suffix(6).enumerated()), id: \.offset) { _, entry in
                Text(entry.message)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(logColor(entry.level))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func logColor(_ level: String) -> Color {
        switch level {
        case "error": return .red
        case "warning": return .orange
        default: return .secondary
        }
    }
}

// MARK: - Git Commit Card

struct GitCommitCard: View {
    let commit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "number")
                .font(.title3)
                .foregroundStyle(.purple)

            Text(commit)
                .font(.system(.caption2, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

struct StatMini: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

private func gaugeGradient(percent: Int) -> Gradient {
    if percent < 60 {
        return Gradient(colors: [.green, .green])
    } else if percent < 80 {
        return Gradient(colors: [.green, .amber])
    } else {
        return Gradient(colors: [.amber, .red])
    }
}
