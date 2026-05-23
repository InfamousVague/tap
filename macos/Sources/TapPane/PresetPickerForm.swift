import SwiftUI
import TapShared

/// Inline preset picker for adding common commands to an existing
/// server. Backed by `CommandPreset.all` — the same catalog used by
/// the relay's `templates` module but client-side for instant UI
/// (no round-trip to list the categories).
///
/// Two states inside the same form, switched by `selected`:
///
///   • **Browse** (default) — search + category-sectioned list of
///     every preset. Tapping a row stages the preset for
///     customisation.
///   • **Customise** — once a preset is selected, the form swaps
///     to a label-editable + variables-fillable view with a live
///     resolved-command preview so the user knows exactly what
///     hits SSH when they hit Add.
///
/// Reuses `store.createCommand(serverId:name:command:description:)`
/// for the actual write — the preset/picker is purely a faster
/// path into the existing endpoint, not a parallel implementation.
struct PresetPickerForm: View {
    @Environment(TapStore.self) private var store
    let serverID: String
    let onClose: () -> Void

    @State private var search = ""
    @State private var selected: CommandPreset?
    @State private var customLabel = ""
    @State private var variableValues: [String: String] = [:]
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        Group {
            if let preset = selected {
                customiseView(preset)
            } else {
                browseView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Browse

    private var browseView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Browse Presets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.stashTextPrimary)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(StashIconButton())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Search field — bare TextField rather than StashField
            // because we don't want the "Search" label above the
            // input; the placeholder + magnifying-glass leading
            // icon already say what it does.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.stashTextTertiary)
                TextField("Search presets…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(8)
            .background(Color.stashBgPrimary)
            .cornerRadius(StashRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: StashRadius.sm)
                    .stroke(Color.stashBorderStrong, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Categorised list. Section headers pin to the top so
            // the user can scroll a long category without losing
            // where they are.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0,
                           pinnedViews: [.sectionHeaders]) {
                    ForEach(filteredCategories, id: \.category.id) { row in
                        Section {
                            ForEach(row.presets) { preset in
                                presetRow(preset)
                                Divider()
                                    .background(Color.stashBorder)
                                    .padding(.leading, 44)
                            }
                        } header: {
                            sectionHeader(row.category, count: row.presets.count)
                        }
                    }
                    if filteredCategories.isEmpty {
                        Text("No presets match \"\(search)\".")
                            .font(.system(size: 11))
                            .foregroundColor(.stashTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    }
                }
            }
        }
    }

    private func presetRow(_ preset: CommandPreset) -> some View {
        Button {
            selected = preset
            customLabel = preset.name
            variableValues = Dictionary(
                uniqueKeysWithValues: preset.variables.map { ($0.name, "") }
            )
        } label: {
            HStack(spacing: 10) {
                Image(systemName: preset.icon)
                    .font(.system(size: 13))
                    .foregroundColor(.stashTextSecondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(preset.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.stashTextPrimary)
                        if preset.confirm {
                            StashBadge(text: "CONFIRM",
                                       color: .stashWarning,
                                       variant: .subtle)
                        }
                    }
                    Text(preset.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundColor(.stashTextTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ category: PresetCategory,
                               count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.system(size: 10))
                .foregroundColor(.stashTextSecondary)
            Text(category.rawValue.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.stashTextSecondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.stashTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(Divider().background(Color.stashBorder),
                 alignment: .bottom)
    }

    private var filteredCategories:
        [(category: PresetCategory, presets: [CommandPreset])]
    {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if q.isEmpty { return CommandPreset.byCategory() }
        return CommandPreset.byCategory().compactMap { row in
            let hits = row.presets.filter {
                $0.name.lowercased().contains(q)
                || $0.command.lowercased().contains(q)
            }
            return hits.isEmpty
                ? nil
                : (category: row.category, presets: hits)
        }
    }

    // MARK: - Customise

    private func customiseView(_ preset: CommandPreset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with back-to-browse on the left so the
            // selection feels reversible, plus the standard X.
            HStack(spacing: 6) {
                Button {
                    selected = nil
                    error = nil
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Presets")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.stashTextSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(StashIconButton())
            }

            HStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.stashTextSecondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.stashTextPrimary)
                    Text(preset.category.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.stashTextTertiary)
                }
                Spacer()
                if preset.confirm {
                    StashBadge(text: "Needs confirm",
                               color: .stashWarning,
                               variant: .subtle)
                }
            }

            StashField(label: "Label",
                       placeholder: preset.name,
                       text: $customLabel)

            // One field per variable. Variable description is the
            // label (e.g. "Service name") so it's actionable.
            ForEach(preset.variables, id: \.name) { v in
                StashField(label: v.description,
                           placeholder: v.placeholder,
                           text: Binding(
                            get: { variableValues[v.name] ?? "" },
                            set: { variableValues[v.name] = $0 }
                           ))
            }

            // Live preview of the resolved command so the user
            // sees exactly what hits SSH. Unfilled variables
            // remain as `{{name}}` so it's visually obvious what's
            // still missing — same convention the preset catalog
            // itself uses.
            VStack(alignment: .leading, spacing: 4) {
                Text("Resolves to")
                    .font(.system(size: 11))
                    .foregroundColor(.stashTextSecondary)
                Text(resolveCommand(preset))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.stashTextPrimary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.stashBgSecondary)
                    .cornerRadius(StashRadius.sm)
                    .textSelection(.enabled)
            }

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
                    Task { await add(preset) }
                } label: {
                    Text(isWorking ? "Adding…" : "Add")
                }
                .buttonStyle(StashPrimaryButton(disabled: !canSubmit(preset)))
                .disabled(!canSubmit(preset) || isWorking)
            }
        }
        .padding(16)
    }

    private func resolveCommand(_ preset: CommandPreset) -> String {
        var out = preset.command
        for v in preset.variables {
            let val = (variableValues[v.name] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            out = out.replacingOccurrences(
                of: "{{\(v.name)}}",
                // Leave the placeholder in if not filled yet,
                // so the preview shows what's still missing.
                with: val.isEmpty ? "{{\(v.name)}}" : val
            )
        }
        return out
    }

    private func canSubmit(_ preset: CommandPreset) -> Bool {
        let label = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return false }
        return preset.variables.allSatisfy { v in
            !(variableValues[v.name] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        }
    }

    private func add(_ preset: CommandPreset) async {
        isWorking = true
        error = nil
        let label = customLabel.isEmpty ? preset.name : customLabel
        let resolved = resolveCommand(preset)
        do {
            try await store.createCommand(
                serverId: serverID,
                name: label,
                command: resolved,
                description: nil,
                // Preset metadata says whether this is safe to
                // run without a confirm tap (e.g. Uptime / Disk
                // Usage = false, Restart Service / Reboot Server
                // = true). Pass it through so the relay records
                // the right confirm state at create time.
                confirm: preset.confirm
            )
            onClose()
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}
