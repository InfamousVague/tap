use axum::{
    extract::State,
    http::StatusCode,
    Json,
    extract::Path,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::auth::{generate_token, hash_token};

#[derive(Deserialize)]
pub struct AppleSignInRequest {
    pub identity_token: String,
    pub user_identifier: String,
    pub email: Option<String>,
}

/// POST /auth/apple — Sign in with Apple.
/// Verifies the Apple identity token, provisions or finds the user,
/// and returns an API token for the device.
pub async fn apple_sign_in(
    State(state): State<Arc<AppState>>,
    Json(body): Json<AppleSignInRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    // Verify the Apple identity token (JWT)
    let claims = verify_apple_identity_token(&body.identity_token)
        .await
        .map_err(|e| {
            tracing::warn!("Apple token verification failed: {}", e);
            StatusCode::UNAUTHORIZED
        })?;

    // Use the Apple 'sub' claim as the user identifier
    let apple_user_id = claims.sub;

    // Find or create user
    let user_id = state.db.find_or_create_user(&apple_user_id, body.email.as_deref())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Check if this user already has a token for this device type
    let label = format!("apple:{}", apple_user_id);
    if let Ok(Some(existing_token_id)) = state.db.find_token_by_label(&label) {
        let _ = state.db.delete_token(&existing_token_id);
    }

    // Generate new API token
    let token = generate_token();
    let token_hash = hash_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_token(&id, &user_id, &label, &token_hash, Some("apple"))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    tracing::info!("Apple sign-in: user {} ({})", &user_id[..8.min(user_id.len())], &apple_user_id[..8.min(apple_user_id.len())]);

    Ok(Json(serde_json::json!({
        "token": token,
        "user_id": user_id,
    })))
}

#[derive(Debug)]
struct AppleClaims {
    sub: String,
}

/// Verify an Apple identity token JWT.
async fn verify_apple_identity_token(token: &str) -> anyhow::Result<AppleClaims> {
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        anyhow::bail!("Invalid JWT format");
    }

    use base64::Engine;
    let header_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD
        .decode(parts[0])?;
    let header: serde_json::Value = serde_json::from_slice(&header_bytes)?;
    let kid = header["kid"].as_str()
        .ok_or_else(|| anyhow::anyhow!("Missing kid in JWT header"))?;

    let client = reqwest::Client::new();
    let keys_response = client
        .get("https://appleid.apple.com/auth/keys")
        .send()
        .await?
        .json::<serde_json::Value>()
        .await?;

    let keys = keys_response["keys"].as_array()
        .ok_or_else(|| anyhow::anyhow!("Invalid Apple JWKS response"))?;

    let matching_key = keys.iter()
        .find(|k| k["kid"].as_str() == Some(kid))
        .ok_or_else(|| anyhow::anyhow!("No matching Apple public key for kid: {}", kid))?;

    let n = matching_key["n"].as_str()
        .ok_or_else(|| anyhow::anyhow!("Missing 'n' in Apple key"))?;
    let e = matching_key["e"].as_str()
        .ok_or_else(|| anyhow::anyhow!("Missing 'e' in Apple key"))?;

    let n_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(n)?;
    let e_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(e)?;

    use rsa::{RsaPublicKey, pkcs1v15::VerifyingKey, BigUint};
    use sha2::Sha256;
    use signature::Verifier;

    let public_key = RsaPublicKey::new(
        BigUint::from_bytes_be(&n_bytes),
        BigUint::from_bytes_be(&e_bytes),
    )?;

    let verifying_key = VerifyingKey::<Sha256>::new(public_key);
    let message = format!("{}.{}", parts[0], parts[1]);
    let signature_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[2])?;
    let signature = rsa::pkcs1v15::Signature::try_from(signature_bytes.as_slice())?;

    verifying_key.verify(message.as_bytes(), &signature)?;

    let claims_bytes = base64::engine::general_purpose::URL_SAFE_NO_PAD.decode(parts[1])?;
    let claims: serde_json::Value = serde_json::from_slice(&claims_bytes)?;

    let iss = claims["iss"].as_str().unwrap_or("");
    if iss != "https://appleid.apple.com" {
        anyhow::bail!("Invalid issuer: {}", iss);
    }

    let aud = claims["aud"].as_str().unwrap_or("");
    let valid_audiences = [
        "com.mattssoftware.tap.watchkitapp",
        "com.mattssoftware.tap",
        "com.mattssoftware.tap.macos",
    ];
    if !valid_audiences.contains(&aud) {
        anyhow::bail!("Invalid audience: {}", aud);
    }

    let exp = claims["exp"].as_i64().unwrap_or(0);
    let now = chrono::Utc::now().timestamp();
    if now > exp {
        anyhow::bail!("Token expired");
    }

    let sub = claims["sub"].as_str()
        .ok_or_else(|| anyhow::anyhow!("Missing sub claim"))?
        .to_string();

    Ok(AppleClaims { sub })
}

/// POST /auth/setup — first-time setup (creates first admin user + token)
pub async fn setup(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let count = state.db.token_count()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if count > 0 {
        return Err(StatusCode::CONFLICT);
    }

    // Create an admin user
    let user_id = state.db.find_or_create_user("setup:admin", None)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let token = generate_token();
    let token_hash = hash_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_token(&id, &user_id, "Setup token", &token_hash, Some("cli"))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::json!({
        "token": token,
        "id": id,
        "user_id": user_id,
    })))
}

#[derive(Deserialize)]
pub struct CreateTokenRequest {
    pub label: String,
    pub device_type: Option<String>,
}

/// POST /auth/token — create a new API token (requires auth)
pub async fn create_token(
    State(state): State<Arc<AppState>>,
    axum::extract::Extension(user): axum::extract::Extension<crate::auth::middleware::UserId>,
    Json(body): Json<CreateTokenRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let token = generate_token();
    let token_hash = hash_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_token(&id, &user.0, &body.label, &token_hash, body.device_type.as_deref())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({
        "id": id,
        "token": token,
        "label": body.label,
        "device_type": body.device_type,
    }))))
}

/// DELETE /auth/token/:id — revoke a token
pub async fn revoke_token(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_token(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}
