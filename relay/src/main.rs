mod auth;
mod config;
mod db;
mod routes;
mod ssh;
mod templates;

use std::sync::Arc;
use tokio::sync::Mutex;
use tracing_subscriber::EnvFilter;

use crate::config::RelayConfig;
use crate::db::Database;
use crate::ssh::SshPool;

pub struct AppState {
    pub db: Database,
    pub ssh_pool: Arc<Mutex<SshPool>>,
    pub config: RelayConfig,
    pub master_key: Option<[u8; 32]>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("tap_relay=info".parse()?))
        .init();

    tracing::info!("Starting Tap Relay v{}", env!("CARGO_PKG_VERSION"));

    // Load config
    let config = RelayConfig::load()?;
    tracing::info!("Config loaded from {:?}", config.resolved_path());

    // Initialize database
    let db = Database::open(&config.data_dir())?;
    db.run_migrations()?;
    tracing::info!("Database initialized");

    // Auto-import SSH config on first run
    if config.import.auto_import_ssh_config && db.server_count()? == 0 {
        match ssh::import_ssh_config(&db) {
            Ok(count) => tracing::info!("Imported {} servers from ~/.ssh/config", count),
            Err(e) => tracing::warn!("SSH config import failed: {}", e),
        }
    }

    // Setup or unlock master passphrase
    let master_key = auth::setup_or_unlock(&db, &config).await?;

    // Create app state
    let state = Arc::new(AppState {
        db,
        ssh_pool: Arc::new(Mutex::new(SshPool::new(&config.ssh))),
        config: config.clone(),
        master_key: Some(master_key),
    });

    // Start background tasks
    let health_state = Arc::clone(&state);
    tokio::spawn(async move {
        ssh::health_loop(health_state).await;
    });

    let cleanup_state = Arc::clone(&state);
    tokio::spawn(async move {
        ssh::pool_cleanup_loop(cleanup_state).await;
    });

    // Build router
    let app = routes::build_router(Arc::clone(&state));

    // Bind and serve
    let addr = format!("{}:{}", config.server.host, config.server.port);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("Tap Relay listening on {}", addr);

    axum::serve(listener, app).await?;

    Ok(())
}
