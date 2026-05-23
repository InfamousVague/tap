import SwiftUI

// MARK: - Add Server

/// Quick add-server sheet. The full provisioning flow (password +
/// connection verify + bulk commands) lives elsewhere in TapMac; the
/// popover sheet is intentionally minimal — name, host, port, user —
/// which is the 90% case. Power users can still use the (eventually
/// re-attached) window for the full provision flow.
struct AddServerSheet: View {
    @Environment(TapStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var host = ""
    @State private var portString = "22"
    @State private var username = "root"
    @State private var password = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sheetHeader(title: "Add Server", dismiss: dismiss)

            StashField(label: "Name", placeholder: "production",
                       text: $name, width: 240)
            StashField(label: "Host", placeholder: "203.0.113.10",
                       text: $host, width: 240, isMonospaced: true)
            HStack {
                StashField(label: "Port", placeholder: "22",
                           text: $portString, width: 80)
                StashField(label: "User", placeholder: "root",
                           text: $username, width: 140)
            }
            StashSecureField(label: "Password",
                             placeholder: "SSH password",
                             text: $password, width: 240)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
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
        .padding(20)
        .frame(width: 340)
        .background(Color.stashBgPrimary)
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
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Add Command

struct AddCommandSheet: View {
    @Environment(TapStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let serverID: String
    @State private var name = ""
    @State private var command = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sheetHeader(title: "Add Command", dismiss: dismiss)

            StashField(label: "Label", placeholder: "Restart nginx",
                       text: $name, width: 240)
            StashField(label: "Command",
                       placeholder: "systemctl restart nginx",
                       text: $command, width: 240, isMonospaced: true)

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
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
        .padding(20)
        .frame(width: 340)
        .background(Color.stashBgPrimary)
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
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}

// MARK: - Adhoc Command

struct AdhocCommandSheet: View {
    @Environment(TapStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let server: Server
    @State private var command = ""
    @State private var output: ExecResponse?
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sheetHeader(title: "Adhoc on \(server.name)", dismiss: dismiss)

            StashField(label: "Command",
                       placeholder: "uptime",
                       text: $command, width: 280, isMonospaced: true)

            if let output {
                AdhocOutputBlock(output: output)
            }

            if let error {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.stashError)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
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
        .padding(20)
        .frame(width: 380)
        .background(Color.stashBgPrimary)
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

struct CommandOutputSheet: View {
    @Environment(\.dismiss) private var dismiss
    let response: ExecResponse
    let commandString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sheetHeader(title: "Output", dismiss: dismiss)

            Text(commandString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.stashTextSecondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.stashBgSecondary)
                .cornerRadius(StashRadius.sm)

            AdhocOutputBlock(output: response)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(StashPrimaryButton())
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Color.stashBgPrimary)
    }
}

// MARK: - Helpers

@ViewBuilder
private func sheetHeader(title: String,
                         dismiss: DismissAction) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.stashTextPrimary)
        Spacer()
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
        }
        .buttonStyle(StashIconButton())
    }
}
