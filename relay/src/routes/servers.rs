use axum::{
    extract::{Extension, Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::{NewServer, NewCommand, Server};
use crate::ssh::import_ssh_config;

pub async fn list(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<Vec<Server>>, StatusCode> {
    state.db.list_servers(&user.0)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

pub async fn create(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<NewServer>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let id = state.db.create_server(&body, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((
        StatusCode::CREATED,
        Json(serde_json::json!({ "id": id })),
    ))
}

pub async fn update(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
    Json(body): Json<NewServer>,
) -> Result<StatusCode, StatusCode> {
    state.db.update_server(&id, &user.0, &body)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::OK)
}

pub async fn delete_server(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<StatusCode, StatusCode> {
    state.db.delete_server(&id, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

pub async fn ping(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let server = state.db.get_server(&id, &user.0)
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

/// POST /servers/import — bulk import servers + commands from JSON
pub async fn bulk_import(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<BulkImportRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let mut servers_created = 0;
    let mut commands_created = 0;

    // Use the relay's SSH key for all imported servers
    let relay_key_id = state.db.find_key_by_label("relay")
        .ok().flatten();

    for entry in &body.servers {
        let new_server = NewServer {
            name: entry.name.clone(),
            host: entry.host.clone(),
            port: entry.port.unwrap_or(22),
            user: entry.user.clone().unwrap_or_else(|| "root".to_string()),
            key_id: relay_key_id.clone(),
            sort_order: entry.sort_order.unwrap_or(0),
        };

        let server_id = state.db.create_server(&new_server, &user.0)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        servers_created += 1;

        for (i, cmd) in entry.commands.iter().enumerate() {
            let new_cmd = NewCommand {
                server_id: server_id.clone(),
                label: cmd.label.clone(),
                command: cmd.command.clone(),
                confirm: cmd.confirm.unwrap_or(false),
                timeout_sec: cmd.timeout_sec.unwrap_or(30),
                sort_order: cmd.sort_order.unwrap_or(i as i32),
                pinned: cmd.pinned.unwrap_or(false),
            };
            state.db.create_command(&new_cmd)
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
            commands_created += 1;
        }
    }

    tracing::info!("Bulk import for user {}: {} servers, {} commands", &user.0[..8.min(user.0.len())], servers_created, commands_created);

    Ok(Json(serde_json::json!({
        "servers_created": servers_created,
        "commands_created": commands_created,
    })))
}

#[derive(Deserialize)]
pub struct BulkImportRequest {
    pub servers: Vec<ServerImport>,
}

#[derive(Deserialize)]
pub struct ServerImport {
    pub name: String,
    pub host: String,
    pub port: Option<u16>,
    pub user: Option<String>,
    pub sort_order: Option<i32>,
    #[serde(default)]
    pub commands: Vec<CommandImport>,
}

#[derive(Deserialize)]
pub struct CommandImport {
    pub label: String,
    pub command: String,
    pub confirm: Option<bool>,
    pub timeout_sec: Option<u32>,
    pub sort_order: Option<i32>,
    pub pinned: Option<bool>,
}

pub async fn import_config(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let count = import_ssh_config(&state.db, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(Json(serde_json::json!({ "imported": count })))
}
