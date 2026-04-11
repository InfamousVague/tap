use axum::{
    extract::{Path, State},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::db::NewCommand;
use crate::templates::TEMPLATES;

/// GET /templates — list all available command templates
pub async fn list() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "templates": &*TEMPLATES }))
}

#[derive(Deserialize)]
pub struct FromTemplateRequest {
    pub template_id: String,
    pub variables: Option<std::collections::HashMap<String, String>>,
}

/// POST /servers/:id/commands/from-template — create a command from a template
pub async fn create_from_template(
    State(state): State<Arc<AppState>>,
    Path(server_id): Path<String>,
    Json(body): Json<FromTemplateRequest>,
) -> Result<(StatusCode, Json<serde_json::Value>), StatusCode> {
    let template = TEMPLATES.iter()
        .find(|t| t.id == body.template_id)
        .ok_or(StatusCode::NOT_FOUND)?;

    // Substitute variables
    let mut command = template.command.clone();
    if let Some(vars) = &body.variables {
        for (key, value) in vars {
            command = command.replace(&format!("{{{{{}}}}}", key), value);
        }
    }

    let new_cmd = NewCommand {
        server_id: server_id.clone(),
        label: template.label.clone(),
        command,
        confirm: template.confirm,
        timeout_sec: template.timeout_sec,
        sort_order: 0,
        pinned: false,
    };

    let id = state.db.create_command(&new_cmd)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok((StatusCode::CREATED, Json(serde_json::json!({ "id": id }))))
}
