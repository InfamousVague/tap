use axum::{
    extract::{Request, State},
    http::StatusCode,
    middleware::Next,
    response::Response,
};
use std::sync::Arc;

use crate::AppState;
use super::verify_token;

/// Auth middleware — extracts Bearer token from Authorization header,
/// verifies it against stored Argon2 hashes, and injects token_id into extensions.
pub async fn auth_middleware(
    State(state): State<Arc<AppState>>,
    mut req: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let auth_header = req.headers()
        .get("authorization")
        .and_then(|v| v.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;

    let token = auth_header.strip_prefix("Bearer ")
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Check token against all stored hashes
    let token_hashes = state.db.all_token_hashes()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut matched_id = None;
    for (id, hash) in &token_hashes {
        if verify_token(token, hash) {
            matched_id = Some(id.clone());
            break;
        }
    }

    let token_id = matched_id.ok_or(StatusCode::UNAUTHORIZED)?;

    // Update last_used
    let _ = state.db.update_token_last_used(&token_id);

    // Store token_id in request extensions for downstream handlers
    req.extensions_mut().insert(TokenId(token_id));

    Ok(next.run(req).await)
}

#[derive(Clone, Debug)]
pub struct TokenId(pub String);
