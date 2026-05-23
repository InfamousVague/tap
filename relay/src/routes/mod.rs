mod servers;
mod commands;
mod exec;
mod keys;
mod auth_routes;
mod apple_web;
mod health;
mod history;
mod config_route;
mod templates;
mod ws;
mod setup;
mod overview;

use std::sync::Arc;
use axum::{
    Router,
    middleware,
    routing::{get, post, put, delete},
};
use tower_http::cors::CorsLayer;
use tower_http::trace::TraceLayer;
use tower_governor::{governor::GovernorConfigBuilder, GovernorLayer, key_extractor::SmartIpKeyExtractor};

use crate::AppState;
use crate::auth::auth_middleware;

pub fn build_router(state: Arc<AppState>) -> Router {
    // Rate limiting: 2 requests/sec replenish, burst of 60
    let governor_conf = Arc::new(
        GovernorConfigBuilder::default()
            .per_second(2)
            .burst_size(60)
            .key_extractor(SmartIpKeyExtractor)
            .finish()
            .expect("Failed to build rate limiter"),
    );
    let rate_limit_layer = GovernorLayer { config: governor_conf };

    // Public routes (no auth required)
    let public = Router::new()
        .route("/auth/apple", post(auth_routes::apple_sign_in))
        // macOS SIWA via ASWebAuthenticationSession lands here (form-
        // post from Apple). Public because Apple is calling it from
        // its own backend, not the authenticated Tap client.
        .route("/auth/apple/web/callback", post(apple_web::web_callback))
        // Domain verification file Apple polls during Services ID
        // configuration. Served from a path configured under
        // [siwa_web] in relay.toml; 404 until that's wired up.
        .route("/.well-known/apple-developer-domain-association.txt",
               get(apple_web::domain_association))
        // Apple has historically accepted both `.txt` and no-extension
        // variants of the well-known. Serve both off the same handler
        // so we don't get tripped up by a future portal change.
        .route("/.well-known/apple-developer-domain-association",
               get(apple_web::domain_association))
        .route("/auth/setup", post(auth_routes::setup))
        .route("/health", get(health::health_check))
        .route("/connect/:token", get(setup::install_script))
        .route("/setup/register/:token", post(setup::register_server))
        .route("/setup/pubkey", get(setup::pubkey));

    // Protected routes (require valid Bearer token)
    let protected = Router::new()
        // Auth management
        .route("/auth/token", post(auth_routes::create_token))
        .route("/auth/token/:id", delete(auth_routes::revoke_token))
        .route("/auth/user", delete(auth_routes::delete_user))
        // APNs device registration
        .route("/apns/register", post(auth_routes::register_apns_device))
        // Servers
        .route("/servers", get(servers::list).post(servers::create))
        .route("/servers/:id", put(servers::update).delete(servers::delete_server))
        .route("/servers/:id/ping", get(servers::ping))
        .route("/servers/import-ssh-config", post(servers::import_config))
        .route("/servers/import", post(servers::bulk_import))
        // Commands
        .route("/servers/:id/commands", get(commands::list).post(commands::create))
        .route("/commands/:id", put(commands::update).delete(commands::delete_command))
        // Suites
        .route("/servers/:id/suites", get(commands::list_suites).post(commands::create_suite))
        .route("/suites/:id", delete(commands::delete_suite))
        // Execution
        .route("/exec", post(exec::execute))
        .route("/exec/adhoc", post(exec::execute_adhoc))
        // SSH Keys
        .route("/keys", get(keys::list))
        .route("/keys/upload", post(keys::upload))
        .route("/keys/generate", post(keys::generate))
        .route("/keys/:id", delete(keys::delete_key))
        .route("/keys/:id/public", get(keys::get_public))
        // Templates
        .route("/templates", get(templates::list))
        .route("/servers/:id/commands/from-template", post(templates::create_from_template))
        // Config & Overview
        .route("/config", get(config_route::get_config))
        .route("/overview", get(overview::get_overview))
        // History
        .route("/history", get(history::list))
        .route("/history/:id", get(history::get_one))
        // Setup (authenticated — generates setup tokens)
        .route("/setup/token", post(setup::create_setup_token))
        .route("/setup/provision", post(setup::provision_server))
        // WebSocket
        .route("/ws/exec", get(ws::ws_exec))
        .route_layer(middleware::from_fn_with_state(state.clone(), auth_middleware));

    Router::new()
        .merge(public)
        .merge(protected)
        .layer(rate_limit_layer)
        .layer(CorsLayer::permissive())
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}
