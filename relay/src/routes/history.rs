use axum::{
    extract::{Extension, Path, State, Query},
    http::StatusCode,
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::ExecEntry;

#[derive(Deserialize)]
pub struct HistoryQuery {
    pub limit: Option<u32>,
}

/// GET /history — list recent executions (user-scoped)
pub async fn list(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Query(query): Query<HistoryQuery>,
) -> Result<Json<Vec<ExecEntry>>, StatusCode> {
    let limit = query.limit.unwrap_or(50);
    state.db.list_history(&user.0, limit)
        .map(Json)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
}

/// GET /history/:id — single execution detail (user-scoped)
pub async fn get_one(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Path(id): Path<String>,
) -> Result<Json<ExecEntry>, StatusCode> {
    state.db.get_history_entry(&id, &user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .map(Json)
        .ok_or(StatusCode::NOT_FOUND)
}
