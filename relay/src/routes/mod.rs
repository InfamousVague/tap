mod servers;
mod commands;
mod exec;
mod keys;
mod auth_routes;
mod health;
mod history;
mod config_route;
mod templates;
mod ws;

use std::sync::Arc;
use axum::{
    Router,
    middleware,
    routing::{get, post, put, delete},
};
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;

use crate::AppState;
use crate::auth::auth_middleware;

pub fn build_router(state: Arc<AppState>) -> Router {
    // Public routes (no auth required)
    let public = Router::new()
        .route("/auth/setup", post(auth_routes::setup))
        .route("/health", get(health::health_check));

    // Protected routes (require valid Bearer token)
    let protected = Router::new()
        // Auth management
        .route("/auth/token", post(auth_routes::create_token))
        .route("/auth/token/{id}", delete(auth_routes::revoke_token))
        // Servers
        .route("/servers", get(servers::list).post(servers::create))
        .route("/servers/{id}", put(servers::update).delete(servers::delete_server))
        .route("/servers/{id}/ping", get(servers::ping))
        .route("/servers/import-ssh-config", post(servers::import_config))
        // Commands
        .route("/servers/{id}/commands", get(commands::list).post(commands::create))
        .route("/commands/{id}", put(commands::update).delete(commands::delete_command))
        // Suites
        .route("/servers/{id}/suites", get(commands::list_suites).post(commands::create_suite))
        .route("/suites/{id}", delete(commands::delete_suite))
        // Execution
        .route("/exec", post(exec::execute))
        .route("/exec/adhoc", post(exec::execute_adhoc))
        // SSH Keys
        .route("/keys", get(keys::list))
        .route("/keys/upload", post(keys::upload))
        .route("/keys/generate", post(keys::generate))
        .route("/keys/{id}", delete(keys::delete_key))
        .route("/keys/{id}/public", get(keys::get_public))
        // Templates
        .route("/templates", get(templates::list))
        .route("/servers/{id}/commands/from-template", post(templates::create_from_template))
        // Config
        .route("/config", get(config_route::get_config))
        // History
        .route("/history", get(history::list))
        .route("/history/{id}", get(history::get_one))
        // WebSocket
        .route("/ws/exec", get(ws::ws_exec))
        .route_layer(middleware::from_fn_with_state(state.clone(), auth_middleware));

    Router::new()
        .merge(public)
        .merge(protected)
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
