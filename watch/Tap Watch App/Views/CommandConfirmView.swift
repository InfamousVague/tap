import SwiftUI

struct CommandConfirmView: View {
    let command: Command
    let server: Server
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToResult = false
    @State private var showWarning = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: showWarning)
                    .shadow(color: .orange.opacity(0.3), radius: 6)

                Text(command.label)
                    .font(.headline)

                Text("on \(server.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(command.command)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )

                HStack(spacing: 8) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.gray)

                    Button {
                        HapticService.shared.play(.confirm)
                        navigateToResult = true
                    } label: {
                        Text("Run")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.amber)
                }
            }
            .padding()
        }
        .navigationTitle("Confirm")
        .navigationDestination(isPresented: $navigateToResult) {
            CommandRunView(command: command, server: server)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showWarning = true
            }
        }
    }
}
