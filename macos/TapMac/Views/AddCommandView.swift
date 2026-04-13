import SwiftUI

struct AddCommandView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let serverId: String

    @State private var name = ""
    @State private var command = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPresets = true

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Add Command", onCancel: { dismiss() })

            Divider()
                .background(Color.stashBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preset browser
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            StashSectionHeader(title: "From Preset")
                            Spacer()
                            Button(action: { withAnimation { showPresets.toggle() } }) {
                                Image(systemName: showPresets ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.stashTextTertiary)
                            }
                            .buttonStyle(StashIconButton(color: .stashTextTertiary, size: 22))
                        }

                        if showPresets {
                            presetBrowser
                        }
                    }

                    // Manual entry
                    StashSectionHeader(title: "Or Enter Manually")

                    VStack(spacing: 12) {
                        StashField(label: "Name", placeholder: "e.g. Restart Nginx", text: $name)
                        StashField(label: "Command", placeholder: "e.g. sudo systemctl restart nginx", text: $command, isMonospaced: true)
                        StashField(label: "Description", placeholder: "Optional", text: $description)
                    }
                    .stashCard()
                }
                .padding(20)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.stashError)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }

            Divider()
                .background(Color.stashBorder)

            HStack {
                Spacer()
                Button(action: { addCommand() }) {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.stashBgPrimary)
                        }
                        Text("Add Command")
                    }
                }
                .buttonStyle(StashPrimaryButton(disabled: name.isEmpty || command.isEmpty || isLoading))
                .disabled(name.isEmpty || command.isEmpty || isLoading)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 560, height: 580)
        .background(Color.stashBgPrimary)
    }

    // MARK: - Preset Browser

    private var presetBrowser: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CommandPreset.byCategory(), id: \.category) { group in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: group.category.icon)
                            .font(.system(size: 10))
                            .foregroundColor(.stashTextTertiary)
                        Text(group.category.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.stashTextTertiary)
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(group.presets) { preset in
                            Button(action: { selectPreset(preset) }) {
                                HStack(spacing: 5) {
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 10))
                                    Text(preset.name)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.stashTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: StashRadius.sm)
                                        .fill(Color.stashBgSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: StashRadius.sm)
                                        .stroke(Color.stashBorderStrong, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .stashCard()
    }

    private func selectPreset(_ preset: CommandPreset) {
        name = preset.name
        command = preset.command
        description = ""
        withAnimation { showPresets = false }
    }

    private func addCommand() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await appState.createCommand(
                    serverId: serverId,
                    name: name,
                    command: command,
                    description: description.isEmpty ? nil : description
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - Flow Layout (horizontal wrapping)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
