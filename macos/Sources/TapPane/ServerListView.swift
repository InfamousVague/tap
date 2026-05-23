import SwiftUI
import TapShared

/// Main signed-in popover view. Header → scrolling server list with
/// expandable command rows → footer with "+ Server", "Adhoc", and
/// "Sign Out" actions. Replaces the prior TapMac sidebar/detail
/// split; the popover doesn't have width for two columns, so each
/// server is a disclosure section that holds its own commands.
struct ServerListView: View {
    @Environment(TapStore.self) private var store

    @State private var expandedServerID: String?
    @State private var showingAddServer = false
    @State private var showingAdhoc = false
    @State private var adhocServer: Server?
    @State private var addCommandFor: Server?
    @State private var commandOutput: CommandOutputContext?
    @State private var runningCommandID: String?

    var body: some View {
        // State-driven view switch. Used to use `.sheet(…)` modifiers
        // but a sheet inside an NSPopover with `.transient`
        // behaviour gets nuked the moment the user tabs away from
        // the launcher — Apple destroys the sheet window when the
        // popover dismisses, and the form's @State for typed-in
        // values goes with it. Rendering the form inline as the
        // pane's main content (state lives in this View's @State,
        // the parent NSPopover keeps its contentViewController
        // alive across hide/show) preserves what the user typed
        // across tab-outs and popover reopens.
        Group {
            if showingAddServer {
                AddServerForm(onClose: { showingAddServer = false })
            } else if let server = adhocServer {
                AdhocCommandForm(server: server,
                                 onClose: { adhocServer = nil })
            } else if let server = addCommandFor {
                AddCommandForm(serverID: server.id,
                               onClose: { addCommandFor = nil })
            } else if let ctx = commandOutput {
                CommandOutputView(response: ctx.response,
                                  commandString: ctx.commandString,
                                  onClose: { commandOutput = nil })
            } else {
                VStack(spacing: 0) {
                    header
                    Divider().background(Color.stashBorder)
                    scrollingServerList
                    Divider().background(Color.stashBorder)
                    footer
                }
            }
        }
        .task {
            await store.loadConfig()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                // Small squircle chip of the v2 server-tapped logo.
                // Reads as the brand mark at header scale while the
                // tracking-1.5 "TAP" text carries the typographic
                // weight — same pattern as Espresso / Uninstaller.
                Image(nsImage: TapBrand.logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 4, style: .continuous))
                Text("TAP")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isLoading {
                ProgressView().scaleEffect(0.5).tint(.stashAmber)
            }
            Button {
                Task { await store.loadConfig() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(StashIconButton())
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: Scrolling server list

    private var scrollingServerList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if store.servers.isEmpty && !store.isLoading {
                    emptyState
                        .padding(.top, 80)
                } else {
                    ForEach(store.servers) { server in
                        ServerSection(
                            server: server,
                            isExpanded: expandedServerID == server.id,
                            runningCommandID: runningCommandID,
                            onToggle: { toggleExpanded(server.id) },
                            onRun: { runCommand(server: server, command: $0) },
                            onAddCommand: { addCommandFor = server },
                            onAdhoc: { adhocServer = server },
                            onDelete: { deleteServer(server) }
                        )
                    }
                }

                if let err = store.errorMessage {
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundColor(.stashError)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.stashError.opacity(0.08))
                        .cornerRadius(StashRadius.sm)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 36))
                .foregroundColor(.stashTextTertiary)
            Text("No servers yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.stashTextPrimary)
            Text("Add one to start running commands")
                .font(.system(size: 11))
                .foregroundColor(.stashTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                showingAddServer = true
            } label: {
                Label("Server", systemImage: "plus")
            }
            .buttonStyle(StashSecondaryButton())

            Spacer()

            Menu {
                Button("Sign Out", role: .destructive) {
                    store.signOut()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Actions

    private func toggleExpanded(_ id: String) {
        withAnimation(.easeInOut(duration: 0.18)) {
            expandedServerID = (expandedServerID == id) ? nil : id
        }
    }

    private func runCommand(server: Server, command: Command) {
        runningCommandID = command.id
        Task { @MainActor in
            do {
                let result = try await store.executeCommand(
                    serverId: server.id, commandId: command.id
                )
                commandOutput = CommandOutputContext(
                    response: result, commandString: command.command
                )
            } catch {
                store.errorMessage = "Execute failed: \(error.localizedDescription)"
            }
            runningCommandID = nil
        }
    }

    private func deleteServer(_ server: Server) {
        Task { @MainActor in
            await store.deleteServer(server)
            if expandedServerID == server.id { expandedServerID = nil }
        }
    }
}

// MARK: - Server section (collapsible)

private struct ServerSection: View {
    let server: Server
    let isExpanded: Bool
    let runningCommandID: String?
    let onToggle: () -> Void
    let onRun: (Command) -> Void
    let onAddCommand: () -> Void
    let onAdhoc: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Server header row
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    StashStatusDot(status: server.displayStatus, size: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.stashTextPrimary)
                        Text(server.host)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.stashTextTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let latency = server.latencyMs {
                        Text("\(latency)ms")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.stashTextTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.stashTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedBody
                    .transition(.opacity)
            }
        }
        .background(
            isExpanded
                ? Color.stashBgSecondary.opacity(0.6)
                : Color.clear
        )
        .cornerRadius(StashRadius.sm)
        .padding(.horizontal, 8)
        .alert("Delete server?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will permanently delete “\(server.name)” and all its commands.")
        }
    }

    private var expandedBody: some View {
        VStack(spacing: 0) {
            Divider().background(Color.stashBorder).padding(.horizontal, 12)

            if let commands = server.commands, !commands.isEmpty {
                ForEach(commands) { command in
                    CommandRow(
                        command: command,
                        isRunning: runningCommandID == command.id,
                        onRun: { onRun(command) }
                    )
                }
            } else {
                Text("No commands yet")
                    .font(.system(size: 11))
                    .foregroundColor(.stashTextTertiary)
                    .padding(.vertical, 8)
            }

            HStack(spacing: 6) {
                Button(action: onAddCommand) {
                    Label("Add Command", systemImage: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(StashGhostButton())

                Button(action: onAdhoc) {
                    Label("Adhoc", systemImage: "terminal")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(StashGhostButton())

                Spacer()

                Button { showingDeleteConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(StashDestructiveButton())
                .help("Delete server")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Command row

private struct CommandRow: View {
    let command: Command
    let isRunning: Bool
    let onRun: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconForCommand(command.command))
                .font(.system(size: 12))
                .foregroundColor(.stashTextTertiary)
                .frame(width: 18)
            Text(command.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.stashTextPrimary)
                .lineLimit(1)
            if command.pinned == true {
                StashBadge(text: "Pin", color: .stashAmber, variant: .subtle)
            }
            Spacer()
            if isRunning {
                ProgressView().scaleEffect(0.5).tint(.stashAmber)
                    .frame(width: 22, height: 22)
            } else {
                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                }
                .buttonStyle(StashIconButton(
                    color: isHovered ? .stashAmber : .stashTextTertiary
                ))
                .help("Run")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            isHovered ? Color.white.opacity(0.02) : Color.clear
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

/// Lightweight SF-symbol picker for command rows. Same heuristics
/// as the prior `CommandRowView.commandIcon` in the window app —
/// just lifted out so the popover and any future widget can share
/// the mapping.
func iconForCommand(_ cmd: String) -> String {
    let c = cmd.lowercased()
    if c.contains("reboot") || c.contains("shutdown") { return "power" }
    if c.contains("restart") { return "arrow.clockwise.circle" }
    if c.contains("reload") { return "arrow.clockwise" }
    if c.contains("status") || c.contains("health") { return "stethoscope" }
    if c.contains("log") || c.contains("journal") { return "doc.text" }
    if c.contains("docker") { return "shippingbox" }
    if c.contains("git") { return "arrow.triangle.branch" }
    if c.contains("nginx") { return "globe" }
    if c.contains("redis") || c.contains("postgres") || c.contains("mysql") {
        return "cylinder"
    }
    if c.hasPrefix("df ") { return "internaldrive" }
    if c.hasPrefix("free ") { return "memorychip" }
    if c == "uptime" || c == "uptime -p" { return "cpu" }
    if c.hasPrefix("ss ") || c.contains("netstat") { return "network" }
    if c.hasPrefix("pm2") { return "chart.bar" }
    return "terminal"
}

// MARK: - CommandOutput context (sheet payload)

struct CommandOutputContext: Identifiable {
    let id = UUID()
    let response: ExecResponse
    let commandString: String
}
