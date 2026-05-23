import SwiftUI
import WidgetKit
import TapShared

/// `.systemMedium` Tap Commands — 4 one-tap command rows. Each row
/// is a `Button(intent: ExecuteCommandIntent(commandId:))`, sized to
/// fit two-by-two in the tile. Tapping fires the relay's `/exec`
/// endpoint via the host (`openAppWhenRun = true`); the widget
/// refreshes on the next reload-all-timelines trigger when the host
/// finishes the call.
struct CommandsMediumView: View {
    let entry: TapEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("TAP")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                    .widgetAccentable()
                Spacer()
                if entry.isStale {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("stale")
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                }
                Button(intent: RefreshIntent()) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Refresh")
            }

            if !entry.state.signedIn {
                signedOutBody
            } else if entry.state.recentCommands.isEmpty {
                emptyBody
            } else {
                commandsGrid
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private var signedOutBody: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text("Sign in to Tap")
                .font(.system(size: 13, weight: .semibold))
            Text("Open the Tap menu-bar app to sign in with Apple")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .widgetAccentable()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyBody: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Image(systemName: "terminal")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("No commands yet")
                .font(.system(size: 11, weight: .medium))
            Text("Open Tap to add commands to your servers")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .widgetAccentable()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var commandsGrid: some View {
        // 2x2 grid of the first 4 recent/pinned commands. Each row
        // gets the server name in the subtitle so the user can tell
        // which "Restart" they're firing (matters when you have
        // production + staging both with a Restart command).
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 6),
                      GridItem(.flexible(), spacing: 6)],
            spacing: 6
        ) {
            ForEach(entry.state.recentCommands.prefix(4)) { cmd in
                Button(intent: ExecuteCommandIntent(commandId: cmd.id)) {
                    CommandTile(command: cmd)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Visual inside a Commands widget button. Label on top, server
/// name below in a smaller dimmer typeface. Keeps the button square
/// enough to fit two across on the medium tile.
private struct CommandTile: View {
    let command: WidgetCommand

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconForCommandID(command.label))
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(command.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(command.serverName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// Same heuristics as TapPane's `iconForCommand`, lifted into the
/// widget bundle since the widget doesn't link TapPane. Kept in
/// lock-step manually — small enough not to need a shared file.
private func iconForCommandID(_ label: String) -> String {
    let l = label.lowercased()
    if l.contains("reboot") || l.contains("shutdown") { return "power" }
    if l.contains("restart") { return "arrow.clockwise.circle" }
    if l.contains("reload") { return "arrow.clockwise" }
    if l.contains("status") || l.contains("health") { return "stethoscope" }
    if l.contains("log") { return "doc.text" }
    if l.contains("docker") { return "shippingbox" }
    if l.contains("deploy") || l.contains("git") { return "arrow.triangle.branch" }
    if l.contains("nginx") { return "globe" }
    if l.contains("disk") { return "internaldrive" }
    if l.contains("mem") { return "memorychip" }
    if l.contains("up") { return "cpu" }
    return "terminal"
}
