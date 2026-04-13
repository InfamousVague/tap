import SwiftUI

struct AdhocCommandView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    let server: Server

    @State private var command = ""
    @State private var isRunning = false
    @State private var output: ExecResponse?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Run Command on \(server.name)", onCancel: { dismiss() })

            Divider()
                .background(Color.stashBorder)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Enter command...", text: $command)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .background(Color.stashBgSecondary)
                        .cornerRadius(StashRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: StashRadius.sm)
                                .stroke(Color.stashBorderStrong, lineWidth: 1)
                        )
                        .onSubmit { runCommand() }

                    Button(action: { runCommand() }) {
                        Text("Run")
                    }
                    .buttonStyle(StashPrimaryButton(disabled: command.isEmpty || isRunning))
                    .disabled(command.isEmpty || isRunning)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if isRunning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.stashAmber)
                        Text("Executing...")
                            .font(.subheadline)
                            .foregroundColor(.stashTextSecondary)
                    }
                    .padding()
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.stashError)
                        .font(.caption)
                        .padding(.horizontal, 20)
                }

                if let output = output {
                    Divider()
                        .background(Color.stashBorder)
                    outputView(output)
                }

                Spacer()
            }
        }
        .frame(width: 700, height: 500)
        .background(Color.stashBgPrimary)
    }

    private func outputView(_ result: ExecResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    if let exitCode = result.exitCode {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(exitCode == 0 ? Color.stashSuccess : Color.stashError)
                                .frame(width: 8, height: 8)
                            Text("Exit: \(exitCode)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.stashTextSecondary)
                        }
                    }
                    if let duration = result.duration {
                        Text(String(format: "%.2fs", duration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.stashTextTertiary)
                    }
                    Spacer()
                }

                if let stdout = result.stdout, !stdout.isEmpty {
                    Text(stdout)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.stashTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let stderr = result.stderr, !stderr.isEmpty {
                    Text(stderr)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.stashError)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(Color.stashBgSecondary)
        .cornerRadius(StashRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: StashRadius.md)
                .stroke(Color.stashBorder, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func runCommand() {
        guard !command.isEmpty else { return }
        isRunning = true
        errorMessage = nil
        output = nil
        Task {
            do {
                output = try await appState.executeAdhoc(serverId: server.id, command: command)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }
}
