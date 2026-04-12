import SwiftUI
import AVFoundation

struct SetupView: View {
    @EnvironmentObject var appState: AppState
    @State private var relayURL = ""
    @State private var token = ""
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.amber)

                    Text("Tap")
                        .font(.title2.bold())

                    Text("Connect to your relay to get started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showManualEntry = true
                    } label: {
                        Label("Enter Manually", systemImage: "keyboard")
                    }

                    if showManualEntry {
                        VStack(spacing: 12) {
                            TextField("Relay URL", text: $relayURL)
                                .textContentType(.URL)
                                .autocorrectionDisabled()

                            SecureField("API Token", text: $token)

                            Button("Connect") {
                                guard !relayURL.isEmpty, !token.isEmpty else { return }
                                HapticService.shared.play(.confirm)
                                appState.configure(relayURL: relayURL, token: token)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.amber)
                            .disabled(relayURL.isEmpty || token.isEmpty)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Setup")
        }
    }
}

// Amber color extension
extension Color {
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
}

extension ShapeStyle where Self == Color {
    static var amber: Color { .amber }
}
