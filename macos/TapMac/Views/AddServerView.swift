import SwiftUI

struct AddServerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var serverName = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = "root"
    @State private var password = ""
    @State private var commandsJSON = ""
    @State private var useJSONEntry = false

    // Individual command entry
    @State private var commands: [NewCommand] = []
    @State private var newCmdName = ""
    @State private var newCmdCommand = ""
    @State private var newCmdDescription = ""

    // Preset selection
    @State private var selectedPresets: Set<String> = []
    @State private var showingAllPresets = false
    @State private var presetVariables: [String: [String: String]] = [:] // [presetId: [varName: value]]

    // Provisioning state
    @State private var isProvisioning = false
    @State private var provisionStep = ""
    @State private var provisionError: String?
    @State private var provisionSuccess = false
    @State private var provisionResult: ProvisionResponse?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader(title: "Add Server", onCancel: { dismiss() })

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
        .frame(width: 640, height: 750)
        .background(Color.stashBgPrimary)
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection Details
                VStack(alignment: .leading, spacing: 10) {
                    StashSectionHeader(title: "Connection Details")

                    VStack(spacing: 12) {
                        StashField(label: "Server Name", placeholder: "My Server", text: $serverName)
                        StashField(label: "Host / IP", placeholder: "192.168.1.100", text: $host)
                        StashField(label: "Port", placeholder: "22", text: $port, width: 100)
                        StashField(label: "Username", placeholder: "root", text: $username)
                        StashSecureField(label: "Password", placeholder: "Password", text: $password)
                    }
                    .stashCard()
                }

                // Suggested Commands (Presets)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        StashSectionHeader(title: "Suggested Commands")
                        Spacer()
                        Button(action: { showingAllPresets.toggle() }) {
                            Text(showingAllPresets ? "Show Less" : "Browse All")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(StashGhostButton(color: .stashAmber, activeColor: .stashAmber400))
                    }

                    if showingAllPresets {
                        allPresetsGrid
                    } else {
                        suggestedPresetsGrid
                    }

                    // Variable inputs for selected presets that need them
                    presetVariableInputs
                }

                // Custom Commands Section
                VStack(alignment: .leading, spacing: 10) {
                    StashSectionHeader(title: "Custom Commands (Optional)")

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Use JSON entry", isOn: $useJSONEntry)
                            .tint(.stashAmber)
                            .foregroundColor(.stashTextPrimary)

                        if useJSONEntry {
                            jsonCommandEntry
                        } else {
                            individualCommandEntry
                        }
                    }
                    .stashCard()
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
                        Text("Connect")
                    }
                    .buttonStyle(StashPrimaryButton(disabled: !isFormValid))
                    .disabled(!isFormValid)
                }
            }
            .padding(20)
        }
    }

    private var jsonCommandEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("JSON array of commands:")
                .font(.caption)
                .foregroundColor(.stashTextSecondary)
            TextEditor(text: $commandsJSON)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.stashTextPrimary)
                .scrollContentBackground(.hidden)
                .frame(height: 120)
                .padding(8)
                .background(Color.stashBgPrimary)
                .cornerRadius(StashRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: StashRadius.sm)
                        .stroke(Color.stashBorderStrong, lineWidth: 1)
                )
            Text("Format: [{\"name\": \"...\", \"command\": \"...\", \"description\": \"...\"}]")
                .font(.caption2)
                .foregroundColor(.stashTextTertiary)
        }
    }

    private var individualCommandEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !commands.isEmpty {
                ForEach(Array(commands.enumerated()), id: \.offset) { index, cmd in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cmd.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.stashTextPrimary)
                            Text(cmd.command)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.stashTextTertiary)
                        }
                        Spacer()
                        Button(action: { commands.remove(at: index) }) {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(StashIconButton(color: .stashTextTertiary, size: 24))
                    }
                    .padding(10)
                    .background(Color.stashBgPrimary)
                    .cornerRadius(StashRadius.sm)
                }
            }

            Divider()
                .background(Color.stashBorder)

            HStack(spacing: 8) {
                TextField("Name", text: $newCmdName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.stashBgPrimary)
                    .cornerRadius(StashRadius.sm)
                    .overlay(RoundedRectangle(cornerRadius: StashRadius.sm).stroke(Color.stashBorderStrong, lineWidth: 1))
                    .frame(width: 120)
                TextField("Command", text: $newCmdCommand)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(Color.stashBgPrimary)
                    .cornerRadius(StashRadius.sm)
                    .overlay(RoundedRectangle(cornerRadius: StashRadius.sm).stroke(Color.stashBorderStrong, lineWidth: 1))
                TextField("Description", text: $newCmdDescription)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.stashBgPrimary)
                    .cornerRadius(StashRadius.sm)
                    .overlay(RoundedRectangle(cornerRadius: StashRadius.sm).stroke(Color.stashBorderStrong, lineWidth: 1))
                    .frame(width: 140)
                Button("Add") { addCommand() }
                    .buttonStyle(StashGhostButton(color: .stashAmber, activeColor: .stashAmber400))
                    .disabled(newCmdName.isEmpty || newCmdCommand.isEmpty)
            }
        }
    }

    // MARK: - Suggested Presets (quick picks)

    private var suggestedPresetsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ], spacing: 8) {
            ForEach(CommandPreset.suggestedForNewServer) { preset in
                PresetChip(
                    preset: preset,
                    isSelected: selectedPresets.contains(preset.id),
                    onToggle: { togglePreset(preset) }
                )
            }
        }
        .stashCard()
    }

    // MARK: - All Presets by Category

    private var allPresetsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(CommandPreset.byCategory(), id: \.category) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: group.category.icon)
                            .font(.system(size: 11))
                            .foregroundColor(.stashTextTertiary)
                        Text(group.category.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.stashTextTertiary)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ], spacing: 8) {
                        ForEach(group.presets) { preset in
                            PresetChip(
                                preset: preset,
                                isSelected: selectedPresets.contains(preset.id),
                                onToggle: { togglePreset(preset) }
                            )
                        }
                    }
                }
            }
        }
        .stashCard()
    }

    // MARK: - Variable Inputs for selected presets

    @ViewBuilder
    private var presetVariableInputs: some View {
        let presetsWithVars = CommandPreset.all.filter {
            selectedPresets.contains($0.id) && !$0.variables.isEmpty
        }
        if !presetsWithVars.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                StashSectionHeader(title: "Configure Variables")

                VStack(spacing: 12) {
                    ForEach(presetsWithVars) { preset in
                        ForEach(preset.variables, id: \.name) { variable in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.stashTextSecondary)
                                    Text(variable.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.stashTextTertiary)
                                }
                                .frame(width: 120, alignment: .leading)

                                TextField(variable.placeholder, text: Binding(
                                    get: { presetVariables[preset.id]?[variable.name] ?? "" },
                                    set: {
                                        if presetVariables[preset.id] == nil {
                                            presetVariables[preset.id] = [:]
                                        }
                                        presetVariables[preset.id]?[variable.name] = $0
                                    }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))
                                .padding(8)
                                .background(Color.stashBgPrimary)
                                .cornerRadius(StashRadius.sm)
                                .overlay(RoundedRectangle(cornerRadius: StashRadius.sm).stroke(Color.stashBorderStrong, lineWidth: 1))
                            }
                        }
                    }
                }
                .stashCard()
            }
        }
    }

    private func togglePreset(_ preset: CommandPreset) {
        if selectedPresets.contains(preset.id) {
            selectedPresets.remove(preset.id)
            presetVariables.removeValue(forKey: preset.id)
        } else {
            selectedPresets.insert(preset.id)
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
            Text("Server Added Successfully!")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.stashTextPrimary)
            if let result = provisionResult {
                VStack(spacing: 8) {
                    if let cmds = result.commandsCreated, cmds > 0 {
                        Label("\(cmds) commands created", systemImage: "terminal")
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
        !serverName.isEmpty && !host.isEmpty && !password.isEmpty && !username.isEmpty
    }

    private func addCommand() {
        let cmd = NewCommand(
            name: newCmdName,
            command: newCmdCommand,
            description: newCmdDescription.isEmpty ? nil : newCmdDescription
        )
        commands.append(cmd)
        newCmdName = ""
        newCmdCommand = ""
        newCmdDescription = ""
    }

    private func startProvisioning() {
        isProvisioning = true
        provisionError = nil

        let parsedCommands = buildCommands()

        Task {
            provisionStep = "Connecting..."
            try? await Task.sleep(nanoseconds: 500_000_000)

            provisionStep = "Installing SSH key..."
            try? await Task.sleep(nanoseconds: 300_000_000)

            provisionStep = "Registering server..."

            do {
                let portNum = Int(port) ?? 22
                let response = try await appState.provisionServer(
                    host: host,
                    port: portNum,
                    username: username,
                    password: password,
                    name: serverName,
                    commands: parsedCommands
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

    private func buildCommands() -> [NewCommand]? {
        var allCommands: [NewCommand] = []

        // Add preset commands
        for presetId in selectedPresets {
            guard let preset = CommandPreset.all.first(where: { $0.id == presetId }) else { continue }
            var cmd = preset.command
            // Substitute variables
            if let vars = presetVariables[presetId] {
                for (key, value) in vars {
                    cmd = cmd.replacingOccurrences(of: "{{\(key)}}", with: value)
                }
            }
            allCommands.append(NewCommand(name: preset.name, command: cmd, description: nil))
        }

        // Add custom commands
        if useJSONEntry && !commandsJSON.isEmpty {
            if let data = commandsJSON.data(using: .utf8),
               let parsed = try? JSONDecoder().decode([NewCommand].self, from: data) {
                allCommands.append(contentsOf: parsed)
            }
        } else {
            allCommands.append(contentsOf: commands)
        }

        return allCommands.isEmpty ? nil : allCommands
    }
}

// MARK: - Preset Chip

struct PresetChip: View {
    let preset: CommandPreset
    let isSelected: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .stashAmber : .stashTextTertiary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isSelected ? .stashTextPrimary : .stashTextSecondary)
                    Text(preset.command)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.stashAmber)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 14))
                        .foregroundColor(.stashBorderStrong)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .fill(isSelected ? Color.stashAmber.opacity(0.08) : (isHovered ? Color.white.opacity(0.03) : Color.stashBgPrimary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .stroke(isSelected ? Color.stashAmber.opacity(0.3) : Color.stashBorderStrong, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Shared sheet header

func sheetHeader(title: String, onCancel: @escaping () -> Void) -> some View {
    HStack {
        Text(title)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.stashTextPrimary)
        Spacer()
        Button("Cancel") { onCancel() }
            .buttonStyle(StashGhostButton())
            .keyboardShortcut(.cancelAction)
    }
    .padding(20)
}
