import SwiftUI
import UniformTypeIdentifiers

// Context wrapper to pass both the response and command string to the output view
struct CommandOutputContext: Identifiable {
    let id = UUID()
    let response: ExecResponse
    let commandString: String
}

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddServer = false
    @State private var showingImport = false
    @State private var importConfig: ImportableConfig?
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Top border line (matches Stash's border-top on .stash container)
            Rectangle()
                .fill(Color.stashBorder)
                .frame(height: 1)

            HStack(spacing: 0) {
                sidebar
                mainContent
            }
        }
        .background(Color.stashBgPrimary)
        .sheet(isPresented: $showingAddServer) {
            AddServerView()
        }
        .sheet(item: $importConfig) { config in
            ImportConfigView(config: config)
        }
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .task {
            // Always refresh to stay in sync
            if appState.isAuthenticated {
                await appState.loadConfig()
            }
        }
    }

    // MARK: - Sidebar (matches Stash sidebar)

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Drag area for window (since title bar is hidden)
            Color.clear
                .frame(height: 12)

            // Server list header
            HStack {
                Text("SERVERS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.stashTextTertiary)

                Spacer()

                HStack(spacing: 4) {
                    Button(action: { showingAddServer = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stashTextTertiary)
                    }
                    .buttonStyle(StashIconButton(color: .stashTextTertiary, size: 22))

                    Button(action: { showingImport = true }) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.stashTextTertiary)
                    }
                    .buttonStyle(StashIconButton(color: .stashTextTertiary, size: 22))
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Server list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(appState.servers) { server in
                        ServerListItem(
                            server: server,
                            isSelected: appState.selectedServer == server,
                            onSelect: { appState.selectedServer = server }
                        )
                    }
                }
            }

            if appState.servers.isEmpty && !appState.isLoading {
                VStack(spacing: 8) {
                    Text("No servers")
                        .font(.system(size: 12))
                        .foregroundColor(.stashTextTertiary)
                }
                .frame(maxHeight: .infinity)
            }

            Spacer()

            // Sidebar footer (matches Stash's Help/Lock buttons)
            VStack(spacing: 2) {
                Button(action: { Task { await appState.loadConfig() } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(.stashTextTertiary)
                        Text("Refresh")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                }
                .buttonStyle(SidebarNavItem())

                Button(action: { appState.signOut() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14))
                            .foregroundColor(.stashTextTertiary)
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                }
                .buttonStyle(SidebarNavItem())
            }
            .padding(8)
        }
        .frame(width: 220)
        .background(Color.stashBgSecondary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.stashBorder, lineWidth: 1)
        )
        .padding(.leading, 10)
        .padding(.vertical, 10)
    }

    // MARK: - Main content area

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let server = appState.selectedServer {
                ServerDetailPanel(server: server)
            } else {
                // Empty state (matches Stash's detail-empty with radial gradient)
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundColor(.stashTextTertiary)
                    Text("Select a Server")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.stashTextPrimary)
                    Text("Choose a server from the sidebar")
                        .font(.system(size: 13))
                        .foregroundColor(.stashTextTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RadialGradient(
                        colors: [Color.stashAmber.opacity(0.05), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, 10)
    }
}

// MARK: - Sidebar nav item button style (matches Stash's .stash__nav-item)

struct SidebarNavItem: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .stashTextPrimary : .stashTextSecondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.white.opacity(0.04) : Color.clear)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Server list item (matches Stash's .vaults-page__project-item)

struct ServerListItem: View {
    let server: Server
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stashTextPrimary)
                    Text(server.host)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.stashTextTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.stashAmber.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            .overlay(
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isSelected ? Color.stashAmber : Color.clear)
                        .frame(width: 2)
                    Spacer()
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Server detail panel (matches Stash's detail panel)

struct ServerDetailPanel: View {
    @EnvironmentObject var appState: AppState
    let server: Server

    @State private var showingAddCommand = false
    @State private var showingDeleteConfirm = false
    @State private var showingAdhocSheet = false
    @State private var commandOutput: CommandOutputContext?
    @State private var runningCommandId: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Detail header (matches Stash's .vaults-page__detail-header)
            detailHeader

            Divider()
                .background(Color.stashBorder)

            // Commands list
            if let commands = server.commands, !commands.isEmpty {
                commandsList(commands)
            } else {
                emptyCommands
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            AddCommandView(serverId: server.id)
        }
        .sheet(isPresented: $showingAdhocSheet) {
            AdhocCommandView(server: server)
        }
        .sheet(item: $commandOutput) { ctx in
            CommandOutputView(output: ctx.response, commandString: ctx.commandString)
        }
        .alert("Delete Server?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await appState.deleteServer(server) }
            }
        } message: {
            Text("This will permanently delete \"\(server.name)\" and all its commands.")
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 12) {
            // Title + meta
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    StashStatusDot(status: server.displayStatus, size: 8)
                    Text(server.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.stashTextPrimary)
                }
                Text("\(server.user ?? "root")@\(server.host):\(server.port ?? 22)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.stashTextTertiary)
            }

            Spacer()

            // Action buttons (tab-style, matches Stash's detail-tabs area)
            HStack(spacing: 2) {
                DetailTabButton(label: "Run Adhoc", icon: "play.fill", color: .stashAmber) {
                    showingAdhocSheet = true
                }
                DetailTabButton(label: "Add Command", icon: "plus", color: .stashTextSecondary) {
                    showingAddCommand = true
                }
                DetailTabButton(label: "Delete", icon: "trash", color: .stashError) {
                    showingDeleteConfirm = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func commandsList(_ commands: [Command]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(commands) { command in
                    CommandRowView(
                        command: command,
                        isRunning: runningCommandId == command.id,
                        onRun: { runCommand(command) },
                        onDelete: { deleteCommand(command) }
                    )

                    if command.id != commands.last?.id {
                        Divider()
                            .background(Color.stashBorder.opacity(0.5))
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var emptyCommands: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundColor(.stashTextTertiary)
            Text("No Commands")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.stashTextPrimary)
            Text("Add commands to run on this server")
                .font(.system(size: 13))
                .foregroundColor(.stashTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runCommand(_ command: Command) {
        runningCommandId = command.id
        errorMessage = nil
        Task {
            do {
                let result = try await appState.executeCommand(
                    serverId: server.id,
                    commandId: command.id
                )
                commandOutput = CommandOutputContext(response: result, commandString: command.command)
            } catch {
                errorMessage = error.localizedDescription
            }
            runningCommandId = nil
        }
    }

    private func deleteCommand(_ command: Command) {
        Task {
            try? await appState.deleteCommand(id: command.id)
        }
    }
}

// MARK: - Detail tab button (matches Stash's .vaults-page__tab)

struct DetailTabButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isHovered ? color : .stashTextTertiary)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? color.opacity(0.08) : Color.clear)
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

// MARK: - Command row (matches Stash's list row pattern)

struct CommandRowView: View {
    let command: Command
    let isRunning: Bool
    let onRun: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    /// Icon from the preset system
    private var commandIcon: String {
        let cmd = command.command.lowercased()
        if cmd.contains("reboot") || cmd.contains("shutdown") { return "power" }
        if cmd.contains("restart") { return "arrow.clockwise.circle" }
        if cmd.contains("reload") { return "arrow.clockwise" }
        if cmd.contains("status") || cmd.contains("health") { return "stethoscope" }
        if cmd.contains("log") || cmd.contains("journal") { return "doc.text" }
        if cmd.contains("docker") { return "shippingbox" }
        if cmd.contains("git") { return "arrow.triangle.branch" }
        if cmd.contains("nginx") { return "globe" }
        if cmd.contains("redis") || cmd.contains("postgres") || cmd.contains("mysql") { return "cylinder" }
        if cmd.hasPrefix("df ") { return "internaldrive" }
        if cmd.hasPrefix("free ") { return "memorychip" }
        if cmd == "uptime" || cmd == "uptime -p" { return "cpu" }
        if cmd.hasPrefix("ss ") || cmd.contains("netstat") { return "network" }
        if cmd.hasPrefix("pm2") { return "chart.bar" }
        return "terminal"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Command icon
            Image(systemName: commandIcon)
                .font(.system(size: 14))
                .foregroundColor(.stashTextTertiary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(command.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.stashTextPrimary)
                    if command.pinned == true {
                        StashBadge(text: "Pinned", color: .stashAmber)
                    }
                    if command.confirm == true {
                        StashBadge(text: "Confirm", color: .stashWarning)
                    }
                }
                Text(command.command)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.stashTextTertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered || isRunning {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.stashAmber)
                    } else {
                        Button(action: onRun) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.stashAmber)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                                .foregroundColor(.stashTextTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(isHovered ? Color.white.opacity(0.02) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Import helpers

extension MainView {
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                importError = "Permission denied accessing the file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let config = try JSONDecoder().decode(ImportableConfig.self, from: data)

                if config.name.isEmpty {
                    importError = "Config file is missing a \"name\" field."
                    return
                }

                importConfig = config
            } catch {
                importError = "Failed to parse config: \(error.localizedDescription)"
            }

        case .failure(let error):
            importError = "File picker error: \(error.localizedDescription)"
        }
    }
}

struct ImportableConfig: Codable, Identifiable {
    var id: String { name + (host ?? "") }
    let name: String
    let host: String?
    let port: Int?
    let username: String?
    let commands: [ImportableCommand]?
}

struct ImportableCommand: Codable {
    let label: String
    let command: String
    let confirm: Bool?
    let pinned: Bool?
    let sortOrder: Int?
    let timeoutSec: Int?

    enum CodingKeys: String, CodingKey {
        case label, command, confirm, pinned
        case sortOrder = "sort_order"
        case timeoutSec = "timeout_sec"
    }
}
