import SwiftUI

struct CommandRunView: View {
    let command: Command
    let server: Server
    @EnvironmentObject var appState: AppState
    @State private var result: ExecResult?
    @State private var isRunning = true

    var body: some View {
        Group {
            if isRunning {
                runningView
            } else if let result = result {
                resultView(result)
            } else {
                errorView
            }
        }
        .task {
            await execute()
        }
    }

    private var runningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.amber)

            Text("Running...")
                .font(.headline)

            Text(command.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("on \(server.name)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func resultView(_ result: ExecResult) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                // Status icon
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(result.isSuccess ? .green : .red)

                Text(result.isSuccess ? "Success" : "Failed")
                    .font(.headline)

                // Duration
                Text("\(result.durationMs)ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Output
                if !result.displayOutput.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Output")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(truncatedOutput(result.displayOutput))
                            .font(.caption2.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Exit code if non-zero
                if let code = result.exitCode, code != 0 {
                    Text("Exit code: \(code)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title)
                .foregroundStyle(.red)

            Text("Connection Error")
                .font(.headline)

            Text("Command queued for later.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func execute() async {
        HapticService.shared.play(.start)

        result = await appState.executeCommand(
            serverId: server.id,
            commandId: command.id
        )

        isRunning = false

        if let result = result {
            HapticService.shared.playExecutionSequence(success: result.isSuccess)
        }
    }

    /// Truncate output to last 20 lines for watch display
    private func truncatedOutput(_ output: String) -> String {
        let lines = output.components(separatedBy: "\n")
        if lines.count > 20 {
            return "...\n" + lines.suffix(20).joined(separator: "\n")
        }
        return output
    }
}
