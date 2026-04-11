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
pub struct SetupRequest {
    pub passphrase: String,
}

/// POST /auth/setup — first-time setup (creates master passphrase + first token)
/// This is only called if setup hasn't happened yet (no tokens exist)
pub async fn setup(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    // Check if already set up
    let count = state.db.token_count()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if count > 0 {
        return Err(StatusCode::CONFLICT); // Already set up
    }

    // Generate a token
    let token = generate_token();
    let token_hash = hash_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_token(&id, "Setup token", &token_hash, Some("cli"))
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::json!({
        "token": token,
        "id": id,
        "message": "Save this token — it won't be shown again."
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
    Json(body): Json<CreateTokenRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let token = generate_token();
    let token_hash = hash_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let id = uuid::Uuid::new_v4().to_string();
    state.db.store_token(&id, &body.label, &token_hash, body.device_type.as_deref())
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
