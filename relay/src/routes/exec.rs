use axum::{
    extract::{Extension, State},
    http::StatusCode,
    Json,
};
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::{ExecRequest, ExecAdhocRequest, ExecResult, ExecEntry};

pub async fn execute(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<ExecRequest>,
) -> Result<Json<ExecResult>, StatusCode> {
    // Verify server belongs to user
    let server = state.db.get_server(&body.server_id, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Look up the command
    let command = state.db.get_command(&body.command_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Verify command belongs to this server
    if command.server_id != server.id {
        return Err(StatusCode::NOT_FOUND);
    }

    // Execute via SSH pool
    let mut pool = state.ssh_pool.lock().await;
    let result = pool.execute(
        &server.id,
        &server.host,
        server.port,
        &server.user,
        &command.command,
        Some(command.timeout_sec as u64),
        &state,
    ).await;

    // Record in history (if audit enabled)
    if state.config.audit.enabled {
        let entry = ExecEntry {
            id: uuid::Uuid::new_v4().to_string(),
            server_id: server.id.clone(),
            command_id: Some(command.id.clone()),
            suite_id: None,
            command_text: Some(command.command.clone()),
            exit_code: result.exit_code,
            stdout: Some(result.stdout.clone()),
            stderr: Some(result.stderr.clone()),
            duration_ms: Some(result.duration_ms as u32),
            device: None,
            created_at: None,
        };
        let _ = state.db.record_execution(&entry, &user.0);
    }

    Ok(Json(result))
}

pub async fn execute_adhoc(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<ExecAdhocRequest>,
) -> Result<Json<ExecResult>, StatusCode> {
    // Verify server belongs to user
    let server = state.db.get_server(&body.server_id, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    // Execute via SSH pool
    let mut pool = state.ssh_pool.lock().await;
    let result = pool.execute(
        &server.id,
        &server.host,
        server.port,
        &server.user,
        &body.command,
        None,
        &state,
    ).await;

    // Record in history
    if state.config.audit.enabled {
        let entry = ExecEntry {
            id: uuid::Uuid::new_v4().to_string(),
            server_id: server.id.clone(),
            command_id: None,
            suite_id: None,
            command_text: Some(body.command.clone()),
            exit_code: result.exit_code,
            stdout: Some(result.stdout.clone()),
            stderr: Some(result.stderr.clone()),
            duration_ms: Some(result.duration_ms as u32),
            device: None,
            created_at: None,
        };
        let _ = state.db.record_execution(&entry, &user.0);
    }

    Ok(Json(result))
}
