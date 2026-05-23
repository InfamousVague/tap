import SwiftUI
import WidgetKit
import TapShared

/// `.systemSmall` Tap Commands — hero is the server count, with a
/// "Last run" line (most recent execution) and a Refresh button at
/// the bottom. Sign-in prompt when the user hasn't authed yet.
struct CommandsSmallView: View {
    let entry: TapEntry

    var body: some View {
        VStack(spacing: 4) {
            Text("TAP")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            Spacer(minLength: 0)

            if !entry.state.signedIn {
                signedOutBody
            } else {
                signedInBody
            }

            Spacer(minLength: 6)

            // Refresh is the only universal small-widget button —
            // Execute lives on the medium where there's room for
            // command rows. `.bordered` for legibility in dimmed
            // mode (cf. white-on-white .borderedProminent issue).
            Button(intent: RefreshIntent()) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(14)
    }

    private var signedOutBody: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
            Text("Sign in")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(1)
            Text("Open Tap to sign in with Apple")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .widgetAccentable()
        }
    }

    private var signedInBody: some View {
        VStack(spacing: 4) {
            Text("\(entry.state.servers.count)")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(entry.state.servers.count == 1 ? "server" : "servers")
                .font(.caption)
                .foregroundStyle(.secondary)
                .widgetAccentable()

            if let exec = entry.state.lastExec {
                HStack(spacing: 4) {
                    Image(systemName: exec.success
                          ? "checkmark.circle.fill"
                          : "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(exec.success ? .green : .red)
                    Text(exec.commandLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .widgetAccentable()
            }
        }
    }
}
