use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;
use crate::db::{Command, NewCommand, Suite, NewSuite, SuiteStep};

pub async fn list(
    State(state): State<Arc<AppState>>,
    Path(server_id): Path<String>,
) -> Result<Json<Vec<Command>>, StatusCode> {
    state.db.list_commands(&server_id)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create(
    State(state): State<Arc<AppState>>,
    Path(server_id): Path<String>,
    Json(mut body): Json<NewCommand>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    body.server_id = server_id;
    let id = state.db.create_command(&body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({ "id": id }))))
}

pub async fn update(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
    Json(body): Json<NewCommand>,
) -> Result<StatusCode, StatusCode> {
    state.db.update_command(&id, &body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

pub async fn delete_command(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_command(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

// --- Suites ---

pub async fn list_suites(
    State(state): State<Arc<AppState>>,
    Path(server_id): Path<String>,
) -> Result<Json<Vec<Suite>>, StatusCode> {
    state.db.list_suites(&server_id)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create_suite(
    State(state): State<Arc<AppState>>,
    Path(server_id): Path<String>,
    Json(mut body): Json<NewSuite>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    body.server_id = server_id;
    let id = state.db.create_suite(&body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({ "id": id }))))
}

pub async fn delete_suite(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_suite(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}
