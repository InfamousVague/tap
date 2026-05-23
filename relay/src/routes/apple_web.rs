//! Sign in with Apple — macOS web-OAuth flow.
//!
//! Background: macOS Tap can't claim the native
//! `com.apple.developer.applesignin` entitlement under Developer ID
//! distribution (amfid rejects the binary at launch — see
//! tap/macos/Tap.entitlements for the full story). So instead of
//! `ASAuthorizationAppleIDProvider`, the Mac app opens an
//! `ASWebAuthenticationSession` pointed at Apple's OAuth `/authorize`
//! endpoint with `client_id` = the **Services ID**
//! (`com.mattssoftware.tap.signin`), `response_mode=form_post`, and
//! `response_type=code id_token`. Apple POSTs the result here.
//!
//! Identity continuity with iOS/watch is mechanical, not coincidental:
//! the Services ID is **grouped under** the primary App ID
//! `com.mattssoftware.tap`, which is what the native iOS/watch flow
//! uses. Apple guarantees the `sub` claim is stable across all App IDs
//! grouped under the same primary, so the `apple_user_id` we hand to
//! `find_or_create_user` matches whatever the iPhone/Watch session
//! produced — same user row, same Tap bearer if they've ever signed
//! in before on those platforms.
//!
//! Flow:
//!   1. Mac app builds the /authorize URL client-side (state nonce
//!      included for round-trip verification), opens
//!      ASWebAuthenticationSession against it.
//!   2. Apple → POST /auth/apple/web/callback (form-encoded:
//!      `code`, `state`, optional `user`).
//!   3. We mint a 5-minute ES256 client_secret JWT signed with the
//!      SIWA .p8 key (NOT the App Store Connect API key — different
//!      key, different purpose).
//!   4. POST https://appleid.apple.com/auth/token with the code +
//!      client_secret → get back {access_token, id_token, …}.
//!   5. Hand id_token to the existing `verify_apple_identity_token`
//!      so validation logic is shared with the native route.
//!   6. find_or_create_user + issue Tap bearer, then return a 303
//!      redirect to `tap://signin?bearer=…&state=…` so
//!      ASWebAuthenticationSession terminates and hands the URL back
//!      to the macOS app.

use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use axum::{
    extract::State,
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    Form,
};
use jsonwebtoken::{encode, EncodingKey, Header};
use serde::{Deserialize, Serialize};

use crate::auth::{generate_token, hash_token};
use crate::routes::auth_routes::verify_apple_identity_token;
use crate::AppState;

/// Form-encoded POST body Apple sends to `redirect_uri` when
/// `response_mode=form_post`. `state` is round-tripped verbatim;
/// `user` is JSON-encoded and only present on the *first* sign-in
/// for a given Apple ID + Services ID pair (Apple's "tell me about
/// myself only once" model — subsequent sign-ins get the same `sub`
/// in the id_token but no name/email at the OAuth layer).
#[derive(Deserialize, Debug)]
pub struct AppleCallbackForm {
    pub code: String,
    #[serde(default)]
    pub state: Option<String>,
    /// JSON-encoded `{"name":{"firstName":…,"lastName":…},"email":…}`
    /// — Apple wraps it as a string field in the form post. We don't
    /// actually need to parse it: the email claim in the id_token has
    /// what we want, and `find_or_create_user` is keyed on `sub`. Kept
    /// here for completeness / future use if we ever want first-name.
    #[serde(default)]
    #[allow(dead_code)]
    pub user: Option<String>,
    /// Apple sends an error param instead of a code when the user
    /// cancels or something else went wrong. We surface it back in
    /// the redirect so the Mac app can show a useful message.
    #[serde(default)]
    pub error: Option<String>,
}

/// Claims on the **client_secret** JWT we issue to Apple (NOT the
/// id_token Apple issues to us). Apple's spec:
///   iss = team id (10-char alphanumeric)
///   iat = now
///   exp = now + ≤ 6 months (we use 5 min — single-use anyway)
///   aud = "https://appleid.apple.com"
///   sub = client_id (the Services ID)
#[derive(Serialize)]
struct ClientSecretClaims {
    iss: String,
    iat: u64,
    exp: u64,
    aud: &'static str,
    sub: String,
}

/// Apple's `/auth/token` JSON response. We only care about
/// `id_token` (the JWT carrying the `sub`/`email` claims we hand to
/// the existing verifier); `access_token` and `refresh_token` are
/// for follow-up API calls we don't make.
#[derive(Deserialize, Debug)]
struct AppleTokenResponse {
    id_token: String,
    #[serde(default)]
    #[allow(dead_code)]
    access_token: Option<String>,
    #[serde(default)]
    #[allow(dead_code)]
    refresh_token: Option<String>,
    #[serde(default)]
    #[allow(dead_code)]
    expires_in: Option<i64>,
}

/// POST /auth/apple/web/callback — form-post landing from Apple.
///
/// Always responds with a 303 redirect to `tap://signin?…` so
/// `ASWebAuthenticationSession` on the Mac side terminates and hands
/// the URL back to the calling app. On success the query carries
/// `bearer` + `user_id`; on failure it carries `error` so the Mac app
/// can show a useful message instead of a generic "auth failed".
pub async fn web_callback(
    State(state): State<Arc<AppState>>,
    Form(body): Form<AppleCallbackForm>,
) -> Response {
    // Apple sent us an OAuth error instead of a code (user cancelled,
    // invalid_client, whatever) — short-circuit straight to the Mac
    // app with the error so it can show "Sign-in cancelled" etc.
    if let Some(err) = body.error {
        return redirect_to_app(&format!(
            "tap://signin?error={}{}",
            urlencode(&err),
            state_query(&body.state),
        ));
    }

    // Pull SIWA config (set in relay.toml's [siwa_web]). If any of
    // team_id/services_id/key_id/key_path is missing, the relay
    // operator hasn't completed the portal setup; return 501 so the
    // failure is visible in logs rather than crashing.
    let siwa = &state.config.siwa_web;
    if !siwa.is_configured() {
        tracing::error!(
            "SIWA web flow hit /auth/apple/web/callback but \
             [siwa_web] config is incomplete — set team_id, \
             services_id, key_id, key_path in relay.toml"
        );
        return (StatusCode::NOT_IMPLEMENTED,
                "SIWA web flow not configured on this relay").into_response();
    }

    // Mint the client_secret JWT — ES256 signed with the .p8 SIWA
    // private key. Apple validates this against the Services ID's
    // configured key on its end during the /auth/token exchange.
    let client_secret = match build_client_secret(siwa) {
        Ok(s) => s,
        Err(e) => {
            tracing::error!("client_secret mint failed: {}", e);
            return redirect_to_app(&format!(
                "tap://signin?error=server_misconfig{}",
                state_query(&body.state),
            ));
        }
    };

    // Exchange the OAuth code for an id_token. Apple's spec is
    // straight RFC 6749 client_credentials-ish: POST application/x-
    // www-form-urlencoded to /auth/token with code, client_id,
    // client_secret, grant_type, redirect_uri (must match exactly
    // what we registered + sent to /authorize).
    let redirect_uri = format!(
        "https://tap.mattssoftware.com/auth/apple/web/callback"
    );
    let form = [
        ("client_id", siwa.services_id.as_str()),
        ("client_secret", client_secret.as_str()),
        ("code", body.code.as_str()),
        ("grant_type", "authorization_code"),
        ("redirect_uri", redirect_uri.as_str()),
    ];
    let token_resp: AppleTokenResponse = match reqwest::Client::new()
        .post("https://appleid.apple.com/auth/token")
        .form(&form)
        .send()
        .await
    {
        Ok(r) => match r.error_for_status() {
            Ok(r) => match r.json::<AppleTokenResponse>().await {
                Ok(t) => t,
                Err(e) => {
                    tracing::warn!("Apple token response decode failed: {}", e);
                    return redirect_to_app(&format!(
                        "tap://signin?error=token_decode{}",
                        state_query(&body.state),
                    ));
                }
            },
            Err(e) => {
                tracing::warn!("Apple /auth/token rejected the exchange: {}", e);
                return redirect_to_app(&format!(
                    "tap://signin?error=token_exchange{}",
                    state_query(&body.state),
                ));
            }
        },
        Err(e) => {
            tracing::warn!("Apple /auth/token network error: {}", e);
            return redirect_to_app(&format!(
                "tap://signin?error=upstream{}",
                state_query(&body.state),
            ));
        }
    };

    // Validate the id_token through the same path the native iOS/
    // watch flow uses — JWKS lookup, signature check, iss/aud/exp.
    // The Services ID was added to the `valid_audiences` list in
    // auth_routes.rs so this `aud` check passes.
    let claims = match verify_apple_identity_token(&token_resp.id_token).await {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("id_token verification failed: {}", e);
            return redirect_to_app(&format!(
                "tap://signin?error=token_verify{}",
                state_query(&body.state),
            ));
        }
    };

    // Same user-provisioning path as the native flow — keyed on
    // `sub` so an Apple ID that's already signed in on iPhone/Watch
    // resolves to the same `user_id` row.
    let user_id = match state.db.find_or_create_user(&claims.sub, claims.email.as_deref()) {
        Ok(id) => id,
        Err(e) => {
            tracing::error!("find_or_create_user failed: {}", e);
            return redirect_to_app(&format!(
                "tap://signin?error=db{}",
                state_query(&body.state),
            ));
        }
    };

    // One token per device label, matching the native flow's
    // semantics — replace any pre-existing token for this Apple
    // user. Label is suffixed with `:web` so a future change that
    // wants to revoke just web sessions can target them.
    let label = format!("apple:{}:web", claims.sub);
    if let Ok(Some(existing)) = state.db.find_token_by_label(&label) {
        let _ = state.db.delete_token(&existing);
    }

    let bearer = generate_token();
    let bearer_hash = match hash_token(&bearer) {
        Ok(h) => h,
        Err(e) => {
            tracing::error!("hash_token failed: {}", e);
            return redirect_to_app(&format!(
                "tap://signin?error=server{}",
                state_query(&body.state),
            ));
        }
    };
    let id = uuid::Uuid::new_v4().to_string();
    if let Err(e) = state.db.store_token(&id, &user_id, &label, &bearer_hash, Some("apple_web")) {
        tracing::error!("store_token failed: {}", e);
        return redirect_to_app(&format!(
            "tap://signin?error=server{}",
            state_query(&body.state),
        ));
    }

    tracing::info!(
        "SIWA web sign-in: user {} ({})",
        &user_id[..8.min(user_id.len())],
        &claims.sub[..8.min(claims.sub.len())],
    );

    redirect_to_app(&format!(
        "tap://signin?bearer={}&user_id={}{}",
        urlencode(&bearer),
        urlencode(&user_id),
        state_query(&body.state),
    ))
}

/// Build the ES256 client_secret JWT. Apple validates this against
/// the Services ID's configured key during the /auth/token exchange.
///
/// One thing to watch: jsonwebtoken's `EncodingKey::from_ec_pem`
/// expects the raw .p8 contents (PEM-armoured). The .p8 Apple gives
/// you starts with `-----BEGIN PRIVATE KEY-----` — that's PKCS#8,
/// which the crate handles natively.
fn build_client_secret(cfg: &crate::config::SiwaWebConfig) -> anyhow::Result<String> {
    let pem = std::fs::read(&cfg.key_path)
        .map_err(|e| anyhow::anyhow!("read SIWA key at {}: {}", cfg.key_path, e))?;
    let key = EncodingKey::from_ec_pem(&pem)
        .map_err(|e| anyhow::anyhow!("parse SIWA key: {}", e))?;

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| anyhow::anyhow!("clock skew: {}", e))?
        .as_secs();

    let claims = ClientSecretClaims {
        iss: cfg.team_id.clone(),
        iat: now,
        // Apple allows up to ~6 months. We use 5 min because each
        // client_secret is single-use (we mint a fresh one per
        // /auth/token call) and short expiry limits blast radius if
        // the .p8 ever leaks.
        exp: now + 300,
        aud: "https://appleid.apple.com",
        sub: cfg.services_id.clone(),
    };

    let mut header = Header::new(jsonwebtoken::Algorithm::ES256);
    header.kid = Some(cfg.key_id.clone());

    encode(&header, &claims, &key)
        .map_err(|e| anyhow::anyhow!("sign client_secret: {}", e))
}

/// Return a 303 See Other to a non-HTTP scheme. We use 303 instead
/// of 302 so the redirect is unambiguously GET-semantics on the
/// browser side — `tap://` isn't an HTTP scheme but the Web view
/// inside ASWebAuthenticationSession follows the Location header
/// either way; 303 just avoids any "should I re-POST?" gymnastics.
fn redirect_to_app(url: &str) -> Response {
    let mut headers = HeaderMap::new();
    headers.insert(
        header::LOCATION,
        url.parse().unwrap_or_else(|_| "tap://signin?error=bad_redirect".parse().unwrap()),
    );
    // Don't cache the redirect — bearer is in the URL, and we don't
    // want any proxy holding onto it.
    headers.insert(header::CACHE_CONTROL, "no-store".parse().unwrap());
    (StatusCode::SEE_OTHER, headers, "").into_response()
}

/// `&state=…` query suffix if the Mac client included a state nonce
/// in /authorize; empty string otherwise. Mac side verifies state
/// round-tripped correctly before trusting the bearer.
fn state_query(state: &Option<String>) -> String {
    match state {
        Some(s) if !s.is_empty() => format!("&state={}", urlencode(s)),
        _ => String::new(),
    }
}

/// Minimal URL-encode for query values — keeps us off `urlencoding`
/// crate just for this one helper. Encodes everything that isn't
/// alphanumeric / `-_.~`. RFC 3986 unreserved.
fn urlencode(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}

/// GET /.well-known/apple-developer-domain-association.txt — serves
/// the verification file Apple gives you after configuring the
/// Services ID's domain. Path comes from
/// `[siwa_web] domain_association_path` in relay.toml so the deploy
/// process can drop the file wherever and just point us at it.
pub async fn domain_association(
    State(state): State<Arc<AppState>>,
) -> Response {
    let Some(path) = state.config.siwa_web.domain_association_path.as_ref() else {
        return (StatusCode::NOT_FOUND, "no domain association configured").into_response();
    };
    match std::fs::read(path) {
        Ok(bytes) => {
            let mut headers = HeaderMap::new();
            // Apple's verifier is lenient about content-type — both
            // text/plain and application/json have been seen in the
            // wild — but text/plain matches the .txt suffix Apple
            // hands the operator at the portal.
            headers.insert(
                header::CONTENT_TYPE,
                "text/plain; charset=utf-8".parse().unwrap(),
            );
            (StatusCode::OK, headers, bytes).into_response()
        }
        Err(e) => {
            tracing::error!(
                "domain association file at {} unreadable: {}",
                path, e
            );
            (StatusCode::INTERNAL_SERVER_ERROR,
             "domain association configured but unreadable").into_response()
        }
    }
}
