import Foundation
import SwiftData

/// Queued command for offline execution
@Model
class QueuedCommand {
    var id: String
    var serverId: String
    var commandId: String
    var commandLabel: String
    var serverName: String
    var queuedAt: Date
    var status: String // "pending", "executing", "completed", "failed"
    var result: String?

    init(serverId: String, commandId: String, commandLabel: String, serverName: String) {
        self.id = UUID().uuidString
        self.serverId = serverId
        self.commandId = commandId
        self.commandLabel = commandLabel
        self.serverName = serverName
        self.queuedAt = Date()
        self.status = "pending"
    }
}

/// Manages offline command queue — persists commands when no connectivity,
/// executes when connectivity returns
@MainActor
class OfflineQueue: ObservableObject {
    @Published var pendingCount: Int = 0

    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        self.modelContext = context
        refreshCount()
    }

    func enqueue(serverId: String, commandId: String, commandLabel: String, serverName: String) {
        guard let context = modelContext else { return }
        let queued = QueuedCommand(
            serverId: serverId,
            commandId: commandId,
            commandLabel: commandLabel,
            serverName: serverName
        )
        context.insert(queued)
        try? context.save()
        refreshCount()
    }

    func drainQueue(using appState: AppState) async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<QueuedCommand>(
            predicate: #Predicate { $0.status == "pending" },
            sortBy: [SortDescriptor(\.queuedAt)]
        )

        guard let pending = try? context.fetch(descriptor) else { return }

        for command in pending {
            command.status = "executing"
            try? context.save()

            let result = await appState.executeCommand(
                serverId: command.serverId,
                commandId: command.commandId
            )

            if let result = result {
                command.status = result.isSuccess ? "completed" : "failed"
                command.result = result.displayOutput
            } else {
                command.status = "failed"
                command.result = "Execution failed"
            }
            try? context.save()
        }

        refreshCount()
    }

    private func refreshCount() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<QueuedCommand>(
            predicate: #Predicate { $0.status == "pending" }
        )
        pendingCount = (try? context.fetchCount(descriptor)) ?? 0
    }
}
