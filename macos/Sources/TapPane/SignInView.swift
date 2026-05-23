import SwiftUI
import AuthenticationServices

/// Popover-sized sign-in. Identical Sign-in-with-Apple flow as the
/// prior TapMac.app — `ASAuthorizationAppleIDProvider` returns the
/// identity token + user id, the host forwards both to the relay
/// (POST /auth/apple), and the relay returns a bearer token we
/// stash in the login Keychain via `KeychainService`.
struct SignInView: View {
    @Environment(TapStore.self) private var store

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                // The server-tapped logo (v2 brand). Squircle-
                // cropped so the image's blue gradient background
                // doesn't paint a flat tile against the popover
                // material — same shape every macOS app icon takes
                // in Finder / the Dock.
                Image(nsImage: TapBrand.logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 22, style: .continuous))

                Text("Tap")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.stashTextPrimary)

                Text("Command remote for your infrastructure")
                    .font(.system(size: 12))
                    .foregroundColor(.stashTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(width: 240, height: 40)
            .cornerRadius(StashRadius.md)

            if store.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.stashAmber)
            }

            if let error = store.errorMessage {
                Text(error)
                    .foregroundColor(.stashError)
                    .font(.system(size: 11))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let cred = authorization.credential
                    as? ASAuthorizationAppleIDCredential,
                  let identityToken = cred.identityToken,
                  let tokenString = String(data: identityToken,
                                           encoding: .utf8)
            else { return }
            Task { @MainActor in
                await store.signInWithApple(
                    identityToken: tokenString,
                    userIdentifier: cred.user,
                    email: cred.email
                )
            }
        case .failure(let error):
            store.errorMessage =
                "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
}
