import SwiftUI

// Graphical render targets for preset commands. Each template in
// `CommandPresets.ResponseTemplate` gets a SwiftUI view here; the
// existing `CommandOutputView` falls back to the raw-text
// `AdhocOutputBlock` for templates without a custom renderer.
//
// Why this lives separate from CommandPresets.swift: the parsers
// already in CommandPresets only do model construction
// (Parsed* structs). This file does presentation — keep the
// model/view split clean.
//
// Visual language: tinted ring charts for percentage stats
// (disk + memory), stat tiles for grouped numerics (CPU load),
// hero-formatted text for single values (uptime), pill badges
// for binary states (service active / Postgres reachable / etc).
// Matches the visual weight of the iOS Tap status widgets so
// users get the same at-a-glance read across platforms.

// MARK: - Ring chart primitive

/// Half-donut "gauge"-style ring used by the disk + memory
/// outputs. Trim from 0 → percent (0...1); colour grades from
/// green → amber → red as the percent climbs so a glance tells
/// you "fine" vs "running hot" without reading the number.
struct RingChart: View {
    let percent: Int             // 0...100
    let centerLabel: String      // e.g. "46%"
    let bottomLabel: String?     // e.g. "22G of 50G"

    private var fraction: Double { Double(min(max(percent, 0), 100)) / 100 }

    /// Green up through 60%, amber up through 85%, red beyond.
    /// Same thresholds the Apple Hardware Monitor uses for its
    /// disk/memory tints so the colour-coding feels familiar.
    private var ringColor: Color {
        switch percent {
        case ..<60:  return .stashSuccess
        case ..<85:  return .stashAmber
        default:     return .stashError
        }
    }

    var body: some View {
        ZStack {
            // Background ring (greyed-out full circle).
            Circle()
                .stroke(Color.stashBorder, lineWidth: 10)
                .frame(width: 92, height: 92)
            // Foreground arc (trimmed to `fraction`).
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor,
                        style: StrokeStyle(lineWidth: 10,
                                           lineCap: .round))
                .frame(width: 92, height: 92)
                // Start at 12 o'clock instead of 3.
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(centerLabel)
                    .font(.system(size: 22, weight: .semibold,
                                  design: .rounded))
                    .foregroundColor(.stashTextPrimary)
                if let bottomLabel {
                    Text(bottomLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.stashTextTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Disk Usage

struct DiskUsageOutputView: View {
    let parsed: ParsedDiskUsage

    var body: some View {
        VStack(spacing: 10) {
            RingChart(
                percent: parsed.usePercent,
                centerLabel: "\(parsed.usePercent)%",
                bottomLabel: "\(parsed.used) of \(parsed.size)"
            )
            statRow([
                ("Mount", parsed.mountPoint),
                ("Free", parsed.available),
                ("Filesystem", parsed.filesystem),
            ])
        }
    }
}

// MARK: - Memory

struct MemoryOutputView: View {
    let parsed: ParsedMemory

    private var usedGB: String { String(format: "%.1fG", parsed.usedGB) }
    private var totalGB: String { String(format: "%.1fG", parsed.totalGB) }
    private var freeGB: String { String(format: "%.1fG", parsed.freeGB) }

    var body: some View {
        VStack(spacing: 10) {
            RingChart(
                percent: parsed.usePercent,
                centerLabel: "\(parsed.usePercent)%",
                bottomLabel: "\(usedGB) of \(totalGB)"
            )
            statRow([
                ("Used", usedGB),
                ("Free", freeGB),
                ("Total", totalGB),
            ])
        }
    }
}

// MARK: - CPU Load

struct CPULoadOutputView: View {
    let parsed: ParsedCPULoad

    var body: some View {
        VStack(spacing: 10) {
            // Three big stat tiles for the 1-/5-/15-min averages.
            // Coloured by severity assuming a 4-core baseline —
            // anything >2.0 reads red, >1.0 amber, else green.
            // Approximation; we don't have the actual CPU count
            // from `uptime` output. Real number always visible.
            HStack(spacing: 10) {
                loadTile(label: "1 min",  value: parsed.load1)
                loadTile(label: "5 min",  value: parsed.load5)
                loadTile(label: "15 min", value: parsed.load15)
            }
            statRow([
                ("Active users", String(parsed.users)),
            ])
        }
    }

    private func loadTile(label: String, value: Double) -> some View {
        let color: Color = value < 1.0
            ? .stashSuccess
            : (value < 2.0 ? .stashAmber : .stashError)
        return VStack(spacing: 4) {
            Text(String(format: "%.2f", value))
                .font(.system(size: 18, weight: .semibold,
                              design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.stashTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.stashBgSecondary)
        .cornerRadius(StashRadius.sm)
    }
}

// MARK: - Uptime

struct UptimeOutputView: View {
    let raw: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 26))
                .foregroundColor(.stashTextSecondary)
            // `uptime -p` returns "up 5 days, 3 hours, 12 minutes".
            // Strip the leading "up " for cleaner display.
            Text(raw.replacingOccurrences(of: "up ", with: "")
                    .replacingOccurrences(of: "Up ", with: ""))
                .font(.system(size: 16, weight: .semibold,
                              design: .rounded))
                .foregroundColor(.stashTextPrimary)
                .multilineTextAlignment(.center)
            Text("Uptime")
                .font(.system(size: 10))
                .foregroundColor(.stashTextTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - Service Status

struct ServiceStatusOutputView: View {
    let parsed: ParsedServiceStatus

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // Big status dot — green when active+running,
                // amber when active but in a non-running substate
                // (reloading / activating), red when inactive /
                // failed.
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                Text(parsed.subState.uppercased())
                    .font(.system(size: 12, weight: .semibold,
                                  design: .rounded))
                    .foregroundColor(dotColor)
                Spacer()
                Text(parsed.name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.stashTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(dotColor.opacity(0.08))
            .cornerRadius(StashRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .stroke(dotColor.opacity(0.3), lineWidth: 1)
            )

            statRow([
                ("PID", parsed.pid.map(String.init) ?? "—"),
                ("Uptime", parsed.uptime ?? "—"),
            ])
        }
    }

    private var dotColor: Color {
        if !parsed.isActive { return .stashError }
        switch parsed.subState.lowercased() {
        case "running":               return .stashSuccess
        case "exited", "dead",
             "failed", "inactive":    return .stashError
        default:                      return .stashAmber
        }
    }
}

// MARK: - Postgres / Redis (one-line booleans)

struct PingOutputView: View {
    let label: String
    let isReachable: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isReachable
                  ? "checkmark.circle.fill"
                  : "xmark.octagon.fill")
                .font(.system(size: 20))
                .foregroundColor(isReachable
                                 ? .stashSuccess : .stashError)
            VStack(alignment: .leading, spacing: 2) {
                Text(isReachable ? "Reachable" : "Unreachable")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.stashTextPrimary)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.stashTextTertiary)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isReachable ? Color.stashSuccess : Color.stashError)
                .opacity(0.08)
        )
        .cornerRadius(StashRadius.sm)
    }
}

// MARK: - NGINX test (one-line boolean — special-cased label)

struct NginxTestOutputView: View {
    let ok: Bool

    var body: some View {
        PingOutputView(
            label: ok ? "Nginx config syntax OK" : "Config has errors",
            isReachable: ok
        )
    }
}

// MARK: - Stat row helper

/// Two- or three-column read-only stat grid used as a footer
/// under most of the graphical outputs (Mount/Free/Filesystem,
/// PID/Uptime, Used/Free/Total, etc). Keeps the spacing + sizing
/// consistent across templates.
@ViewBuilder
private func statRow(_ pairs: [(String, String)]) -> some View {
    HStack(spacing: 12) {
        ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
            VStack(alignment: .leading, spacing: 1) {
                Text(pair.0.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(.stashTextTertiary)
                Text(pair.1)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.stashTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(.horizontal, 4)
}

// MARK: - Dispatcher

/// Pick the right graphical view for a command + its stdout.
/// Returns nil when the command isn't a recognised preset OR
/// when the parser can't extract structure from the output —
/// the caller falls back to AdhocOutputBlock (raw text) in that
/// case.
@MainActor
struct PresetOutputDispatcher {
    static func view(
        for commandString: String,
        stdout: String
    ) -> AnyView? {
        guard let template = CommandPreset.templateForCommand(commandString)
        else { return nil }

        switch template {
        case .diskUsage:
            guard let p = CommandOutputParser.parseDiskUsage(stdout)
            else { return nil }
            return AnyView(DiskUsageOutputView(parsed: p))

        case .memory:
            guard let p = CommandOutputParser.parseMemory(stdout)
            else { return nil }
            return AnyView(MemoryOutputView(parsed: p))

        case .cpuLoad:
            guard let p = CommandOutputParser.parseCPULoad(stdout)
            else { return nil }
            return AnyView(CPULoadOutputView(parsed: p))

        case .uptime:
            return AnyView(UptimeOutputView(raw: stdout))

        case .serviceStatus:
            guard let p = CommandOutputParser.parseServiceStatus(stdout)
            else { return nil }
            return AnyView(ServiceStatusOutputView(parsed: p))

        case .nginxTest:
            return AnyView(NginxTestOutputView(
                ok: CommandOutputParser.parseNginxTest(stdout)))

        case .postgresReady:
            let ok = stdout.lowercased().contains("accepting connections")
            return AnyView(PingOutputView(
                label: "PostgreSQL", isReachable: ok))

        case .redisStatus:
            let ok = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased() == "PONG"
            return AnyView(PingOutputView(
                label: "Redis", isReachable: ok))

        // The remaining templates (serviceLogs, dockerContainers,
        // dockerStats, pm2Status, connectionCount, topProcesses,
        // gitCommit) fall through to raw text for now — each
        // wants its own per-row visual that's a bigger lift than
        // a single ring/badge can carry. Plumbing's here when
        // someone wants to add them.
        case .serviceLogs, .dockerContainers, .dockerStats,
             .pm2Status, .connectionCount, .topProcesses,
             .gitCommit:
            return nil
        }
    }
}
