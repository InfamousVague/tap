use axum::{
    extract::{Extension, Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::SshKeyMeta;
use russh_keys::PublicKeyBase64;

pub async fn list(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<Vec<SshKeyMeta>>, StatusCode> {
    state.db.list_keys(&user.0)
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
    Extension(user): Extension<UserId>,
    Json(body): Json<UploadKeyRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let master_key = state.master_key
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    let public_key = extract_public_key(&body.private_key)
        .unwrap_or_else(|| "unknown".to_string());

    let encrypted = crate::auth::encrypt(&master_key, body.private_key.as_bytes())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_key_for_user(&id, &user.0, &body.label, &encrypted, &public_key, "ed25519")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({
        "id": id,
        "public_key": public_key,
    }))))
}

pub async fn generate(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<GenerateKeyRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let master_key = state.master_key
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    let key = russh_keys::key::KeyPair::generate_ed25519()
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut pem_buf = Vec::new();
    russh_keys::encode_pkcs8_pem(&key, &mut pem_buf)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let public_key = format!("ssh-ed25519 {} {}", key.public_key_base64(), body.label);

    let encrypted = crate::auth::encrypt(&master_key, &pem_buf)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_key_for_user(&id, &user.0, &body.label, &encrypted, &public_key, "ed25519")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({
        "id": id,
        "public_key": public_key,
    }))))
}

#[derive(Deserialize)]
pub struct GenerateKeyRequest {
    pub label: String,
}

pub async fn delete_key(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_key(&id, &user.0)
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

/// Extract public key from a PEM private key
fn extract_public_key(private_key_pem: &str) -> Option<String> {
    russh_keys::decode_secret_key(private_key_pem, None)
        .ok()
        .map(|kp| format!("ssh-ed25519 {}", kp.public_key_base64()))
}
