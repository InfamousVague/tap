import SwiftUI

struct CommandConfirmView: View {
    let command: Command
    let server: Server
    @EnvironmentObject var appState: AppState
    @State private var navigateToResult = false
    @State private var result: ExecResult?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.amber)

            Text("Run Command?")
                .font(.headline)

            VStack(spacing: 4) {
                Text(command.label)
                    .font(.body)
                Text("on \(server.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(command.command)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Cancel") {
                    // Pop back
                }
                .tint(.gray)

                Button("Run") {
                    HapticService.shared.play(.confirm)
                    navigateToResult = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.amber)
            }
        }
        .padding()
        .navigationDestination(isPresented: $navigateToResult) {
            CommandRunView(command: command, server: server)
        }
    }
}
