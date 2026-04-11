use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;
use crate::db::{NewServer, Server};
use crate::ssh::import_ssh_config;

pub async fn list(
    State(state): State<Arc<AppState>>,
) -> Result<Json<Vec<Server>>, StatusCode> {
    state.db.list_servers()
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create(
    State(state): State<Arc<AppState>>,
    Json(body): Json<NewServer>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let id = state.db.create_server(&body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({ "id": id })),
    ))
}

pub async fn update(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
    Json(body): Json<NewServer>,
) -> Result<StatusCode, StatusCode> {
    state.db.update_server(&id, &body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

pub async fn delete_server(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_server(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn ping(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let server = state.db.get_server(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let mut pool = state.ssh_pool.lock().await;
    let latency = pool.ping(&server.id, &server.host, server.port, &server.user, &state).await;

    let (status, ms) = match latency {
        Some(ms) => ("up", Some(ms)),
        None => ("down", None),
    };

    let _ = state.db.update_server_status(&id, status, ms);

    Ok(Json(serde_json::json!({
        "status": status,
        "latency_ms": ms,
    })))
}

pub async fn import_config(
    State(state): State<Arc<AppState>>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let count = import_ssh_config(&state.db)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::json!({ "imported": count })))
}
