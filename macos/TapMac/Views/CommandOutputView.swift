import SwiftUI

extension ExecResponse: Identifiable {
    var id: String {
        "\(stdout ?? "")\(stderr ?? "")\(exitCode ?? 0)\(duration ?? 0)"
    }
}

struct CommandOutputView: View {
    let output: ExecResponse
    let commandString: String?
    @Environment(\.dismiss) var dismiss

    init(output: ExecResponse, commandString: String? = nil) {
        self.output = output
        self.commandString = commandString
    }

    private var responseTemplate: ResponseTemplate? {
        guard let cmd = commandString else { return nil }
        return CommandPreset.templateForCommand(cmd)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Command Output")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.stashTextPrimary)
                Spacer()

                if let exitCode = output.exitCode {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(exitCode == 0 ? Color.stashSuccess : Color.stashError)
                            .frame(width: 8, height: 8)
                        Text("Exit: \(exitCode)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.stashTextSecondary)
                    }
                }

                if let duration = output.duration {
                    Text(String(format: "%.2fs", duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                        .padding(.leading, 8)
                }

                Button("Close") { dismiss() }
                    .buttonStyle(StashGhostButton())
                    .keyboardShortcut(.cancelAction)
                    .padding(.leading, 12)
            }
            .padding(20)

            Divider()
                .background(Color.stashBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Smart parsed output (if template matches)
                    if let template = responseTemplate,
                       let stdout = output.stdout, !stdout.isEmpty,
                       let parsed = CommandOutputParser.parse(output: stdout, template: template) {
                        smartOutputSection(template: template, parsed: parsed)
                    }

                    // Always show raw output below
                    if let stdout = output.stdout, !stdout.isEmpty {
                        outputSection(title: "stdout", content: stdout, color: .stashTextPrimary)
                    }

                    if let stderr = output.stderr, !stderr.isEmpty {
                        outputSection(title: "stderr", content: stderr, color: .stashError)
                    }

                    if (output.stdout ?? "").isEmpty && (output.stderr ?? "").isEmpty {
                        Text("(no output)")
                            .foregroundColor(.stashTextTertiary)
                            .italic()
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 700, height: 500)
        .background(Color.stashBgPrimary)
    }

    // MARK: - Smart Output Section

    @ViewBuilder
    private func smartOutputSection(template: ResponseTemplate, parsed: Any) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StashSectionHeader(title: "Summary")

            Group {
                switch template {
                case .diskUsage:
                    if let disk = parsed as? ParsedDiskUsage {
                        macDiskUsageView(disk)
                    }
                case .memory:
                    if let mem = parsed as? ParsedMemory {
                        macMemoryView(mem)
                    }
                case .cpuLoad:
                    if let cpu = parsed as? ParsedCPULoad {
                        macCPUView(cpu)
                    }
                case .uptime:
                    if let str = parsed as? String {
                        macUptimeView(str)
                    }
                case .serviceStatus:
                    if let svc = parsed as? ParsedServiceStatus {
                        macServiceView(svc)
                    }
                case .dockerContainers:
                    if let containers = parsed as? [ParsedDockerContainer] {
                        macDockerView(containers)
                    }
                case .nginxTest:
                    if let passed = parsed as? Bool {
                        macStatusBadge(passed: passed, label: passed ? "Nginx config OK" : "Nginx config error")
                    }
                case .postgresReady:
                    if let ready = parsed as? Bool {
                        macStatusBadge(passed: ready, label: ready ? "PostgreSQL accepting connections" : "PostgreSQL not responding")
                    }
                case .redisStatus:
                    if let pong = parsed as? Bool {
                        macStatusBadge(passed: pong, label: pong ? "Redis responding (PONG)" : "Redis not responding")
                    }
                case .connectionCount:
                    if let counts = parsed as? [String: Int] {
                        macConnectionView(counts)
                    }
                default:
                    EmptyView()
                }
            }
            .padding(14)
            .background(Color.stashBgSecondary)
            .cornerRadius(StashRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.md)
                    .stroke(Color.stashBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Mac Smart Views

    private func macDiskUsageView(_ disk: ParsedDiskUsage) -> some View {
        HStack(spacing: 20) {
            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                Text("Disk Usage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.stashTextPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(diskColor(disk.usePercent))
                            .frame(width: geo.size.width * CGFloat(disk.usePercent) / 100.0)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(disk.usePercent)% used")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(diskColor(disk.usePercent))
                    Spacer()
                    Text("\(disk.available) free of \(disk.size)")
                        .font(.caption)
                        .foregroundColor(.stashTextTertiary)
                }
            }
        }
    }

    private func macMemoryView(_ mem: ParsedMemory) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Memory Usage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.stashTextPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(diskColor(mem.usePercent))
                            .frame(width: geo.size.width * CGFloat(mem.usePercent) / 100.0)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(mem.usePercent)% used")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(diskColor(mem.usePercent))
                    Spacer()
                    Text(String(format: "%.1fG / %.1fG", mem.usedGB, mem.totalGB))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                }
            }
        }
    }

    private func macCPUView(_ cpu: ParsedCPULoad) -> some View {
        HStack(spacing: 24) {
            loadIndicator(label: "1 min", value: cpu.load1)
            loadIndicator(label: "5 min", value: cpu.load5)
            loadIndicator(label: "15 min", value: cpu.load15)
        }
    }

    private func loadIndicator(label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.2f", value))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(loadColor(value))
            Text(label)
                .font(.caption)
                .foregroundColor(.stashTextTertiary)
        }
    }

    private func macUptimeView(_ uptime: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.stashSuccess)
            Text(uptime)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.stashTextPrimary)
        }
    }

    private func macServiceView(_ svc: ParsedServiceStatus) -> some View {
        HStack(spacing: 16) {
            Image(systemName: svc.isActive ? "checkmark.shield.fill" : "xmark.shield.fill")
                .font(.title2)
                .foregroundColor(svc.isActive ? .stashSuccess : .stashError)

            VStack(alignment: .leading, spacing: 4) {
                Text(svc.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.stashTextPrimary)
                HStack(spacing: 8) {
                    StashStatusPill(status: svc.isActive ? "up" : "down")
                    if let uptime = svc.uptime {
                        Text(uptime)
                            .font(.caption)
                            .foregroundColor(.stashTextTertiary)
                    }
                }
            }
        }
    }

    private func macDockerView(_ containers: [ParsedDockerContainer]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(containers.enumerated()), id: \.offset) { _, container in
                HStack(spacing: 10) {
                    StashStatusDot(status: container.isRunning ? "up" : "down", size: 8)
                    Text(container.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.stashTextPrimary)
                    Spacer()
                    Text(container.status)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(container.isRunning ? .stashSuccess : .stashError)
                }
            }
        }
    }

    private func macStatusBadge(passed: Bool, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(passed ? .stashSuccess : .stashError)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(passed ? .stashSuccess : .stashError)
        }
    }

    private func macConnectionView(_ counts: [String: Int]) -> some View {
        HStack(spacing: 24) {
            if let total = counts["total"] {
                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.stashAmber)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.stashTextTertiary)
                }
            }
            if let estab = counts["established"] {
                VStack(spacing: 4) {
                    Text("\(estab)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.stashSuccess)
                    Text("Established")
                        .font(.caption)
                        .foregroundColor(.stashTextTertiary)
                }
            }
            if let tw = counts["timewait"] {
                VStack(spacing: 4) {
                    Text("\(tw)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.stashTextSecondary)
                    Text("Time Wait")
                        .font(.caption)
                        .foregroundColor(.stashTextTertiary)
                }
            }
        }
    }

    // MARK: - Raw Output

    private func outputSection(title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StashSectionHeader(title: title)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(color)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(Color.stashBgSecondary)
            .cornerRadius(StashRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.md)
                    .stroke(Color.stashBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Helpers

    private func diskColor(_ percent: Int) -> Color {
        if percent < 60 { return .stashSuccess }
        if percent < 80 { return .stashAmber }
        return .stashError
    }

    private func loadColor(_ load: Double) -> Color {
        if load < 1.0 { return .stashSuccess }
        if load < 2.0 { return .stashAmber }
        return .stashError
    }
}
