import SwiftUI
import TapShared

// Despite the filename, these are **inline forms**, not sheets.
//
// They used to be presented via `.sheet(isPresented:)` inside
// ServerListView, but a sheet inside an NSPopover with `.transient`
// behaviour gets vapourised the moment the user tabs away from the
// launcher — Apple's window for the sheet detaches when the
// popover dismisses and the SwiftUI @State for typed-in form values
// goes with it. Rendering the same content inline as the pane's
// main view (state lives in `ServerListView`'s @State, the parent
// NSPopover keeps its contentViewController alive across hide /
// show) preserves what the user typed.
//
// Each form takes an `onClose: () -> Void` callback the caller flips
// to its own state flag (showingAddServer = false, addCommandFor =
// nil, etc.). No more `@Environment(\.dismiss)` — that was specific
// to the sheet lifecycle.

// MARK: - Add Server

/// Quick add-server form. The full provisioning flow (password +
/// connection verify + bulk commands) lives elsewhere in TapMac; the
/// pane form is intentionally minimal — name, host, port, user —
/// which is the 90% case. Power users can still use the (eventually
/// re-attached) window for the full provision flow.
struct AddServerForm: View {
    @Environment(TapStore.self) private var store
    let onClose: () -> Void

    @State private var name = ""
    @State private var host = ""
    @State private var portString = "22"
    @State private var username = "root"
    @State private var password = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            formHeader(title: "Add Server", onClose: onClose)

            // Fields are stacked label-above-field; each field
            // fills the pane's available width. The Port column in
            // the Port+User row keeps a narrow explicit width
            // since "22" needs ~60pt at most and User should soak
            // up the rest.
            StashField(label: "Name", placeholder: "production",
                       text: $name)
            StashField(label: "Host", placeholder: "203.0.113.10",
                       text: $host, isMonospaced: true)
            HStack(alignment: .top, spacing: 12) {
                StashField(label: "Port", placeholder: "22",
                           text: $portString, width: 70)
                StashField(label: "User", placeholder: "root",
                           text: $username)
            }
            StashSecureField(label: "Password",
                             placeholder: "SSH password",
                             text: $password)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                    .buttonStyle(StashSecondaryButton())
                Button {
                    Task { await provision() }
                } label: {
                    HStack(spacing: 4) {
                        if isWorking {
                            ProgressView().scaleEffect(0.5)
                                .tint(.stashBgPrimary)
                        }
                        Text(isWorking ? "Adding…" : "Add")
                    }
                }
                .buttonStyle(StashPrimaryButton(disabled: !canSubmit))
                .disabled(!canSubmit || isWorking)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var canSubmit: Bool {
        !name.isEmpty && !host.isEmpty && !username.isEmpty
            && !password.isEmpty && Int(portString) != nil
    }

    private func provision() async {
        guard let port = Int(portString) else { return }
        isWorking = true
        error = nil
        do {
            _ = try await store.provisionServer(
                host: host, port: port, username: username,
                password: password, name: name, commands: nil
            )
            onClose()
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Add Command

struct AddCommandForm: View {
    @Environment(TapStore.self) private var store
    let serverID: String
    let onClose: () -> Void

    @State private var name = ""
    @State private var command = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            formHeader(title: "Add Command", onClose: onClose)

            StashField(label: "Label", placeholder: "Restart nginx",
                       text: $name)
            StashField(label: "Command",
                       placeholder: "systemctl restart nginx",
                       text: $command, isMonospaced: true)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                    .buttonStyle(StashSecondaryButton())
                Button {
                    Task { await create() }
                } label: {
                    Text(isWorking ? "Adding…" : "Add")
                }
                .buttonStyle(StashPrimaryButton(disabled: !canSubmit))
                .disabled(!canSubmit || isWorking)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var canSubmit: Bool { !name.isEmpty && !command.isEmpty }

    private func create() async {
        isWorking = true
        error = nil
        do {
            try await store.createCommand(
                serverId: serverID, name: name,
                command: command, description: nil
            )
            onClose()
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Adhoc Command

struct AdhocCommandForm: View {
    @Environment(TapStore.self) private var store
    let server: Server
    let onClose: () -> Void

    @State private var command = ""
    @State private var output: ExecResponse?
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            formHeader(title: "Adhoc on \(server.name)", onClose: onClose)

            StashField(label: "Command",
                       placeholder: "uptime",
                       text: $command, isMonospaced: true)

            if let output {
                AdhocOutputBlock(output: output)
            }

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(StashSecondaryButton())
                Button {
                    Task { await run() }
                } label: {
                    Text(isWorking ? "Running…" : "Run")
                }
                .buttonStyle(StashPrimaryButton(disabled: command.isEmpty))
                .disabled(command.isEmpty || isWorking)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func run() async {
        isWorking = true
        error = nil
        output = nil
        do {
            output = try await store.executeAdhoc(
                serverId: server.id, command: command
            )
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}

private struct AdhocOutputBlock: View {
    let output: ExecResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                StashBadge(
                    text: "Exit \(output.exitCode ?? 0)",
                    color: (output.exitCode ?? 0) == 0
                        ? .stashSuccess : .stashError,
                    variant: .subtle
                )
                if let d = output.duration {
                    Text(String(format: "%.2fs", d))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                }
            }
            if let stdout = output.stdout, !stdout.isEmpty {
                ScrollView {
                    Text(stdout)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.stashTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 140)
                .background(Color.stashBgPrimary)
                .cornerRadius(StashRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: StashRadius.sm)
                        .stroke(Color.stashBorder, lineWidth: 1)
                )
            }
            if let stderr = output.stderr, !stderr.isEmpty {
                Text(stderr)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.stashError)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.stashError.opacity(0.08))
                    .cornerRadius(StashRadius.sm)
            }
        }
    }
}

// MARK: - Command Output

struct CommandOutputView: View {
    let response: ExecResponse
    let commandString: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            formHeader(title: "Output", onClose: onClose)

            Text(commandString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.stashTextSecondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stashBgSecondary)
                .cornerRadius(StashRadius.sm)

            AdhocOutputBlock(output: response)

            Spacer()

            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(StashPrimaryButton())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Helpers

/// Header row used at the top of every inline form: bold title on
/// the left, X button on the right that fires the form's onClose.
/// Was `sheetHeader` taking a `DismissAction` when these were
/// .sheet()-presented; now takes the closure the parent uses to
/// flip its state flag back off.
@ViewBuilder
private func formHeader(title: String,
                        onClose: @escaping () -> Void) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.stashTextPrimary)
        Spacer()
        Button { onClose() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
        }
        .buttonStyle(StashIconButton())
    }
}
