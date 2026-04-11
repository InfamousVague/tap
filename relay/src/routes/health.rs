use axum::{
    extract::State,
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;

/// GET /health — public endpoint, returns all servers with their health status
pub async fn health_check(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let servers = state.db.list_servers()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let health: Vec<serde_json::Value> = servers.iter().map(|s| {
        serde_json::json!({
            "id": s.id,
            "name": s.name,
            "host": s.host,
            "status": s.status,
            "latency_ms": s.latency_ms,
        })
    }).collect();

    Ok(Json(serde_json::json!({
        "relay": "ok",
        "version": env!("CARGO_PKG_VERSION"),
        "servers": health,
    })))
}
