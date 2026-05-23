import SwiftUI
import AuthenticationServices

/// Popover-sized sign-in for the **macOS** Tap pane.
///
/// Why this is different from iOS/watchOS Tap's SignInView: native
/// `ASAuthorizationAppleIDProvider` is unreachable on a Developer ID-
/// signed Mac binary — the `com.apple.developer.applesignin`
/// entitlement fails amfid's pre-launch check no matter what
/// provisioning profile we embed (4 profiles tested; see
/// tap/macos/Tap.entitlements for the full investigation). So
/// instead of the native sheet we open an `ASWebAuthenticationSession`
/// against Apple's OAuth `/authorize` endpoint with `client_id` =
/// our Services ID (`com.mattssoftware.tap.signin`). Apple redirects
/// to `tap.mattssoftware.com/auth/apple/web/callback`, the relay
/// exchanges the code for an id_token, validates it through the
/// same path the iOS/watch native flow uses (find_or_create_user
/// keyed on the JWT's `sub`), and 303s back to `tap://signin?bearer=…`.
/// `ASWebAuthenticationSession` captures the `tap://` redirect and
/// hands us the URL; we pull the bearer out and stash it.
///
/// Identity continuity with iOS/watch: the Services ID is grouped
/// under the primary App ID `com.mattssoftware.tap` (configured at
/// developer.apple.com), so Apple issues the SAME `sub` claim across
/// all three platforms for a given Apple ID. The relay's
/// `find_or_create_user(sub, email)` therefore resolves to the same
/// user row whether the request came from iPhone, Watch, or Mac.
struct SignInView: View {
    @Environment(TapStore.self) private var store
    @State private var presenter = WebSignInPresenter()

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

            // Custom "Sign in with Apple" button — visually mirrors
            // SignInWithAppleButton(.signIn) (white pill, Apple
            // logo + text) but drives ASWebAuthenticationSession
            // instead of the native ASAuthorizationAppleIDProvider
            // path that amfid blocks for Developer ID Mac apps.
            Button {
                presenter.start { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let bearer):
                            await store.signInWithWebBearer(bearer)
                        case .failure(let message):
                            store.errorMessage = message
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 14, weight: .medium))
                    Text("Sign in with Apple")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.black)
                .frame(width: 240, height: 40)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: StashRadius.md))
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)

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
}

// MARK: - ASWebAuthenticationSession driver

/// Owns the in-flight `ASWebAuthenticationSession` so it doesn't get
/// deallocated mid-flow + provides the `ASPresentationAnchor` the
/// system needs to attach the auth sheet. Kept as a separate small
/// type so SignInView stays declarative.
@MainActor
final class WebSignInPresenter: NSObject,
    ASWebAuthenticationPresentationContextProviding
{
    enum Result {
        case success(bearer: String)
        case failure(message: String)
    }

    /// Strong-ref'd so the session doesn't deallocate while Apple's
    /// sheet is up — ASWebAuthenticationSession's completion handler
    /// won't fire if the session itself is dropped.
    private var session: ASWebAuthenticationSession?
    private var expectedState: String?

    /// Apple's OAuth /authorize URL with the parameters our Services
    /// ID config + the relay's /callback expect. State is a UUID we
    /// generate per-attempt and verify on round-trip so a stale
    /// in-flight session can't smuggle in a different user's bearer.
    private func buildAuthorizeURL(state: String) -> URL {
        var c = URLComponents(string: "https://appleid.apple.com/auth/authorize")!
        c.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: "com.mattssoftware.tap.signin"),
            .init(name: "redirect_uri",
                  value: "https://tap.mattssoftware.com/auth/apple/web/callback"),
            // `name` triggers Apple to include the user's
            // display name on first sign-in; `email` triggers the
            // email claim in the id_token. Apple requires
            // response_mode=form_post when either scope is
            // requested — the redirect comes as a POST from
            // Apple's backend to the relay, NOT to this client.
            .init(name: "scope", value: "name email"),
            .init(name: "response_mode", value: "form_post"),
            .init(name: "state", value: state),
        ]
        return c.url!
    }

    func start(completion: @escaping (Result) -> Void) {
        let state = UUID().uuidString
        expectedState = state

        let session = ASWebAuthenticationSession(
            url: buildAuthorizeURL(state: state),
            // The relay's /callback finishes by 303-redirecting to
            // tap://signin?bearer=…&state=…, which trips this
            // callback-scheme matcher and returns the URL to us.
            callbackURLScheme: "tap"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.session = nil
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    completion(.failure(message: "Sign-in cancelled."))
                    return
                }
                if let error {
                    completion(.failure(
                        message: "Sign-in failed: \(error.localizedDescription)"))
                    return
                }
                guard let callbackURL else {
                    completion(.failure(message: "Sign-in returned no callback."))
                    return
                }
                self.handleCallback(callbackURL, completion: completion)
            }
        }
        // `false` so the user's existing appleid.apple.com cookies
        // are available — they typically get a one-tap Touch ID
        // confirmation instead of having to re-enter their password.
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = self
        self.session = session

        if !session.start() {
            completion(.failure(message: "Couldn't open Apple sign-in window."))
        }
    }

    private func handleCallback(_ url: URL,
                                completion: @escaping (Result) -> Void) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            completion(.failure(message: "Couldn't parse sign-in response."))
            return
        }
        let items = comps.queryItems ?? []
        func q(_ k: String) -> String? {
            items.first(where: { $0.name == k })?.value
        }

        // Server side surfaces OAuth errors back to the app via the
        // ?error= query param so we can show something specific
        // rather than a generic "auth failed".
        if let err = q("error"), !err.isEmpty {
            completion(.failure(message: "Sign-in failed: \(err)."))
            return
        }

        // CSRF / replay protection: state was generated this session,
        // round-tripped through Apple + the relay, and must come
        // back verbatim. Anything else = something we didn't start.
        guard let state = q("state"), state == expectedState else {
            completion(.failure(message: "Sign-in state mismatch."))
            return
        }

        guard let bearer = q("bearer"), !bearer.isEmpty else {
            completion(.failure(message: "Sign-in returned no bearer."))
            return
        }

        completion(.success(bearer: bearer))
    }

    // MARK: ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(
        for _: ASWebAuthenticationSession
    ) -> ASPresentationAnchor {
        // System sheet attaches to the menu-bar app's key window
        // when one's available. When Tap is merged into the
        // launcher's popover, the popover's host window fills that
        // role; standalone, our own popover's window does. Fallback
        // to an off-screen anchor window so the session can still
        // surface even if there's no popover currently open.
        if let w = NSApp.keyWindow { return w }
        if let w = NSApp.windows.first(where: { $0.isVisible }) { return w }
        return ASPresentationAnchor()
    }
}
