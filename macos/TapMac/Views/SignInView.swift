import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.stashAmber)

                Text("Tap")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.stashTextPrimary)

                Text("Server Management")
                    .font(.title3)
                    .foregroundColor(.stashTextSecondary)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(width: 280, height: 44)
            .cornerRadius(StashRadius.md)

            if appState.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.stashAmber)
            }

            if let error = appState.errorMessage {
                Text(error)
                    .foregroundColor(.stashError)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.stashBgPrimary)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let identityToken = appleIDCredential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8) {
                let userIdentifier = appleIDCredential.user
                let email = appleIDCredential.email
                Task {
                    await appState.signInWithApple(
                        identityToken: tokenString,
                        userIdentifier: userIdentifier,
                        email: email
                    )
                }
            }
        case .failure(let error):
            appState.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
}
