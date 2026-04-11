use axum::{
    extract::{Path, State, Query},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::db::ExecEntry;

#[derive(Deserialize)]
pub struct HistoryQuery {
    pub limit: Option<u32>,
}

/// GET /history — list recent executions
pub async fn list(
    State(state): State<Arc<AppState>>,
    Query(query): Query<HistoryQuery>,
) -> Result<Json<Vec<ExecEntry>>, StatusCode> {
    let limit = query.limit.unwrap_or(50);
    state.db.list_history(limit)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

/// GET /history/:id — single execution detail
pub async fn get_one(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Result<Json<ExecEntry>, StatusCode> {
    // For now, search through history
    let entries = state.db.list_history(1000)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    entries.into_iter()
        .find(|e| e.id == id)
        .map(Json)
        .ok_or(StatusCode::NOT_FOUND)
}
