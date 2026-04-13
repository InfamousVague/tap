use axum::{
    http::StatusCode,
    Json,
};

/// GET /health — public endpoint, returns relay status (no user data)
pub async fn health_check() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(serde_json::json!({
        "relay": "ok",
        "version": env!("CARGO_PKG_VERSION"),
    })))
}
