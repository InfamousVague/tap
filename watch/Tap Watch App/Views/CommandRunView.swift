import SwiftUI

struct CommandRunView: View {
    let command: Command
    let server: Server
    @EnvironmentObject var appState: AppState
    @State private var result: ExecResult?
    @State private var isRunning = true
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showResult = false

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
        .navigationBarBackButtonHidden(isRunning)
        .task {
            await execute()
        }
    }

    // MARK: - Running view with animated progress ring

    private var runningView: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 4)
                    .frame(width: 64, height: 64)

                // Spinning progress arc
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(colors: [.amber.opacity(0), .amber], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(elapsed * 180))
                    .animation(.linear(duration: 0.1), value: elapsed)

                // Timer in center
                Text(String(format: "%.1f", elapsed))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.amber)
            }

            Text(command.label)
                .font(.headline)
                .lineLimit(1)

            Text(server.name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Result view

    private func resultView(_ result: ExecResult) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                // Animated status icon
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(result.isSuccess ? .green : .red)
                    .symbolEffect(.bounce, value: showResult)
                    .shadow(color: (result.isSuccess ? Color.green : Color.red).opacity(0.4), radius: 8)

                Text(result.isSuccess ? "Success" : "Failed")
                    .font(.headline)

                // Duration + exit code
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(formatDuration(result.durationMs))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if let code = result.exitCode, code != 0 {
                        Text("exit \(code)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.red.opacity(0.15), in: Capsule())
                    }
                }

                // Smart parsed output or raw fallback
                SmartResultView(result: result, command: command)
            }
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showResult = true
            }
        }
    }

    // MARK: - Error view

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 32))
                .foregroundStyle(.red)
                .symbolEffect(.pulse)

            Text("Connection Error")
                .font(.headline)

            Text("Command queued for later.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Execution

    private func execute() async {
        HapticService.shared.play(.start)
        result = await appState.executeCommand(serverId: server.id, commandId: command.id)
        isRunning = false
        timer?.invalidate()

        if let result = result {
            HapticService.shared.playExecutionSequence(success: result.isSuccess)
        }
    }

    private func startTimer() {
        elapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        } else {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
    }

}
