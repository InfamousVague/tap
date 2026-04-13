use axum::{
    extract::{Extension, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;

/// GET /config — full config dump for watch/companion to pull (user-scoped)
pub async fn get_config(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let servers = state.db.list_servers(&user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut server_configs = Vec::new();
    for server in &servers {
        let commands = state.db.list_commands(&server.id)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        let suites = state.db.list_suites(&server.id)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

        server_configs.push(serde_json::json!({
            "id": server.id,
            "name": server.name,
            "host": server.host,
            "port": server.port,
            "user": server.user,
            "status": server.status,
            "latency_ms": server.latency_ms,
            "commands": commands,
            "suites": suites,
        }));
    }

    Ok(Json(serde_json::json!({
        "version": env!("CARGO_PKG_VERSION"),
        "servers": server_configs,
    })))
}
