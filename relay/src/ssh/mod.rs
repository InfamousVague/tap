mod pool;
mod import;

pub use pool::SshPool;
pub use import::import_ssh_config;

use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;

use crate::AppState;

/// Background task: ping all servers every N seconds
pub async fn health_loop(state: Arc<AppState>) {
    let interval = Duration::from_secs(state.config.health.ping_interval_seconds);

    if !state.config.health.enabled {
        tracing::info!("Health pings disabled");
        return;
    }

    loop {
        sleep(interval).await;

        let servers = match state.db.list_servers() {
            Ok(s) => s,
            Err(e) => {
                tracing::error!("Failed to list servers for health check: {}", e);
                continue;
            }
        };

        for server in &servers {
            let mut pool = state.ssh_pool.lock().await;
            let latency = pool.ping(&server.id, &server.host, server.port, &server.user, &state).await;

            let (status, latency_ms) = match latency {
                Some(ms) => ("up", Some(ms)),
                None => ("down", None),
            };

            let prev_status = server.status.as_deref().unwrap_or("unknown");

            if let Err(e) = state.db.update_server_status(&server.id, status, latency_ms) {
                tracing::error!("Failed to update server status: {}", e);
            }

            // Log status changes
            if prev_status == "up" && status == "down" {
                tracing::warn!("Server {} ({}) went DOWN", server.name, server.host);
                // TODO: Send APNs notification
            } else if prev_status == "down" && status == "up" {
                tracing::info!("Server {} ({}) is back UP", server.name, server.host);
            }
        }
    }
}

/// Background task: clean up idle SSH connections
pub async fn pool_cleanup_loop(state: Arc<AppState>) {
    loop {
        sleep(Duration::from_secs(60)).await;
        let mut pool = state.ssh_pool.lock().await;
        pool.cleanup_idle();
    }
}
