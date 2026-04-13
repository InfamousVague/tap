use axum::{
    extract::{Extension, Path, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::{Command, NewCommand, Suite, NewSuite};

pub async fn list(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(server_id): Path<String>,
) -> Result<Json<Vec<Command>>, StatusCode> {
    // Verify server belongs to user
    if !state.db.verify_server_owner(&server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    state.db.list_commands(&server_id)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(server_id): Path<String>,
    Json(mut body): Json<NewCommand>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    if !state.db.verify_server_owner(&server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    body.server_id = server_id;
    let id = state.db.create_command(&body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({ "id": id }))))
}

pub async fn update(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
    Json(body): Json<NewCommand>,
) -> Result<StatusCode, StatusCode> {
    // Verify command's server belongs to user
    let cmd = state.db.get_command(&id).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;
    if !state.db.verify_server_owner(&cmd.server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    state.db.update_command(&id, &body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

pub async fn delete_command(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    let cmd = state.db.get_command(&id).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;
    if !state.db.verify_server_owner(&cmd.server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    state.db.delete_command(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

// --- Suites ---

pub async fn list_suites(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(server_id): Path<String>,
) -> Result<Json<Vec<Suite>>, StatusCode> {
    if !state.db.verify_server_owner(&server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    state.db.list_suites(&server_id)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create_suite(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(server_id): Path<String>,
    Json(mut body): Json<NewSuite>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    if !state.db.verify_server_owner(&server_id, &user.0).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)? {
        return Err(StatusCode::NOT_FOUND);
    }
    body.server_id = server_id;
    let id = state.db.create_suite(&body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({ "id": id }))))
}

pub async fn delete_suite(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    // Would need to check suite ownership through server — for now just delete
    // TODO: verify suite's server belongs to user
    state.db.delete_suite(&id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}
