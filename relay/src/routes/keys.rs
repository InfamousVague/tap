use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::db::SshKeyMeta;

pub async fn list(
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<SshKeyMeta>>, StatusCode> {
    state.db.list_keys()
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

#[derive(Deserialize)]
pub struct UploadKeyRequest {
    pub label: String,
    pub private_key: String,
}

pub async fn upload(
    State(state): State<Arc<AppState>>,
    Json(body): Json<UploadKeyRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let master_key = state.master_key
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    // Extract public key from private key
    // For now, store the key type as ed25519 (most common)
    let public_key = extract_public_key(&body.private_key)
        .unwrap_or_else(|| "unknown".to_string());

    // Encrypt the private key
    let encrypted = crate::auth::encrypt(&master_key, body.private_key.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_key(&id, &body.label, &encrypted, &public_key, "ed25519")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({
        "id": id,
        "public_key": public_key,
    }))))
}

pub async fn generate(
    State(state): State<Arc<AppState>>,
    Json(body): Json<GenerateKeyRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let master_key = state.master_key
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    // Generate Ed25519 keypair
    // TODO: Use russh_keys to generate proper SSH keypair
    // For now, generate a placeholder
    let id = uuid::Uuid::new_v4().to_string();
    let placeholder_private = format!("-----BEGIN OPENSSH PRIVATE KEY-----\ngenerated-{}\n-----END OPENSSH PRIVATE KEY-----", id);
    let placeholder_public = format!("ssh-ed25519 AAAA...placeholder {}", body.label);

    let encrypted = crate::auth::encrypt(&master_key, placeholder_private.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    state.db.store_key(&id, &body.label, &encrypted, &placeholder_public, "ed25519")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({
        "id": id,
        "public_key": placeholder_public,
    }))))
}

#[derive(Deserialize)]
pub struct GenerateKeyRequest {
    pub label: String,
}

pub async fn delete_key(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_key(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn get_public(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let key = state.db.get_encrypted_key(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    Ok(Json(serde_json::json!({
        "id": key.id,
        "public_key": key.public_key,
        "key_type": key.key_type,
    })))
}

/// Try to extract public key from a PEM private key
fn extract_public_key(_private_key_pem: &str) -> Option<String> {
    // TODO: Use russh_keys to properly extract public key
    // russh_keys::decode_secret_key(pem, None).ok()
    //     .map(|kp| kp.public_key().to_string())
    None
}
