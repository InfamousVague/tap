import SwiftUI

struct ImportConfigView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let config: ImportableConfig

    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var password: String = ""
    @State private var selectedCommands: Set<Int>

    @State private var isProvisioning = false
    @State private var provisionStep = ""
    @State private var provisionError: String?
    @State private var provisionSuccess = false
    @State private var provisionResult: ProvisionResponse?

    init(config: ImportableConfig) {
        self.config = config
        _host = State(initialValue: config.host ?? "")
        _port = State(initialValue: String(config.port ?? 22))
        _username = State(initialValue: config.username ?? "root")

        let allIndices = Set(config.commands?.indices.map { $0 } ?? [])
        _selectedCommands = State(initialValue: allIndices)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import: \(config.name)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.stashTextPrimary)
                    if let count = config.commands?.count, count > 0 {
                        Text("\(count) commands")
                            .font(.caption)
                            .foregroundColor(.stashTextSecondary)
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(StashGhostButton())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()
                .background(Color.stashBorder)

            if isProvisioning {
                provisioningView
            } else if provisionSuccess {
                successView
            } else {
                formView
            }
        }
        .frame(width: 620, height: 600)
        .background(Color.stashBgPrimary)
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection details
                VStack(alignment: .leading, spacing: 10) {
                    StashSectionHeader(title: "Connection Details")

                    VStack(spacing: 12) {
                        StashField(label: "Host / IP", placeholder: "192.168.1.100", text: $host)
                        StashField(label: "Port", placeholder: "22", text: $port, width: 100)
                        StashField(label: "Username", placeholder: "root", text: $username)
                        StashSecureField(label: "Password", placeholder: "SSH password", text: $password)
                    }
                    .stashCard()
                }

                // Commands
                if let commands = config.commands, !commands.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        StashSectionHeader(title: "Commands (\(selectedCommands.count)/\(commands.count) selected)")

                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Button(selectedCommands.count == commands.count ? "Deselect All" : "Select All") {
                                    if selectedCommands.count == commands.count {
                                        selectedCommands.removeAll()
                                    } else {
                                        selectedCommands = Set(commands.indices.map { $0 })
                                    }
                                }
                                .buttonStyle(StashGhostButton(color: .stashAmber, activeColor: .stashAmber400))
                                Spacer()
                            }
                            .padding(.bottom, 8)

                            ForEach(Array(commands.enumerated()), id: \.offset) { index, cmd in
                                HStack(spacing: 10) {
                                    Image(systemName: selectedCommands.contains(index) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedCommands.contains(index) ? .stashAmber : .stashTextTertiary)
                                        .onTapGesture {
                                            if selectedCommands.contains(index) {
                                                selectedCommands.remove(index)
                                            } else {
                                                selectedCommands.insert(index)
                                            }
                                        }

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(cmd.label)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.stashTextPrimary)
                                            if cmd.pinned == true {
                                                StashBadge(text: "Pinned", color: .stashAmber)
                                            }
                                            if cmd.confirm == true {
                                                StashBadge(text: "Confirm", color: .stashWarning)
                                            }
                                        }
                                        Text(cmd.command)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.stashTextTertiary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedCommands.contains(index) {
                                        selectedCommands.remove(index)
                                    } else {
                                        selectedCommands.insert(index)
                                    }
                                }

                                if index < commands.count - 1 {
                                    Divider()
                                        .background(Color.stashBorder)
                                }
                            }
                        }
                        .stashCard()
                    }
                }

                // Error
                if let error = provisionError {
                    Text(error)
                        .foregroundColor(.stashError)
                        .font(.caption)
                }

                // Connect Button
                HStack {
                    Spacer()
                    Button(action: { startProvisioning() }) {
                        Text("Connect & Import")
                    }
                    .buttonStyle(StashPrimaryButton(disabled: !isFormValid))
                    .disabled(!isFormValid)
                }
            }
            .padding(20)
        }
    }

    private var provisioningView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(.stashAmber)
            Text(provisionStep)
                .font(.title3)
                .foregroundColor(.stashTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.stashSuccess)
            Text("\(config.name) Connected!")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.stashTextPrimary)
            if let result = provisionResult {
                VStack(spacing: 8) {
                    if let cmds = result.commandsCreated, cmds > 0 {
                        Label("\(cmds) commands imported", systemImage: "terminal")
                            .foregroundColor(.stashTextSecondary)
                    }
                    if let verified = result.connectionVerified {
                        Label(
                            verified ? "Key-based connection verified" : "Connection not yet verified",
                            systemImage: verified ? "lock.shield.fill" : "exclamationmark.triangle"
                        )
                        .foregroundColor(verified ? .stashSuccess : .stashWarning)
                    }
                }
                .font(.subheadline)
            }
            Button(action: { dismiss() }) {
                Text("Done")
            }
            .buttonStyle(StashPrimaryButton())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isFormValid: Bool {
        !host.isEmpty && !password.isEmpty && !username.isEmpty
    }

    private func startProvisioning() {
        isProvisioning = true
        provisionError = nil

        // Build selected commands
        let commands: [NewCommand]? = config.commands.flatMap { allCmds in
            let selected = selectedCommands.sorted().compactMap { idx -> NewCommand? in
                guard idx < allCmds.count else { return nil }
                let cmd = allCmds[idx]
                return NewCommand(name: cmd.label, command: cmd.command, description: nil)
            }
            return selected.isEmpty ? nil : selected
        }

        Task {
            provisionStep = "Connecting to \(host)..."
            do {
                let portNum = Int(port) ?? 22
                let response = try await appState.provisionServer(
                    host: host,
                    port: portNum,
                    username: username,
                    password: password,
                    name: config.name,
                    commands: commands
                )

                if let error = response.error {
                    provisionError = error
                    isProvisioning = false
                } else {
                    provisionStep = "Done!"
                    provisionResult = response
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    isProvisioning = false
                    provisionSuccess = true
                }
            } catch {
                provisionError = error.localizedDescription
                isProvisioning = false
            }
        }
    }
}
