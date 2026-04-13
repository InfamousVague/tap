mod pool;
mod import;

pub use pool::SshPool;
pub use import::import_ssh_config;

use std::sync::Arc;
use std::time::Duration;
use tokio::time::sleep;

use crate::AppState;
use crate::config::RelayConfig;
use crate::db::Database;
use russh_keys::PublicKeyBase64;

/// Ensure the relay has its own SSH keypair for connecting to managed servers.
/// Generates one on first run and stores it encrypted in the database.
pub async fn ensure_relay_keypair(db: &Database, master_key: &[u8; 32], config: &RelayConfig) -> anyhow::Result<()> {
    // Check if relay key already exists
    if let Ok(Some(_)) = db.find_key_by_label("relay") {
        tracing::info!("Relay SSH key exists");
        return Ok(());
    }

    tracing::info!("Generating relay SSH keypair...");

    // Generate Ed25519 keypair using russh-keys
    let key = russh_keys::key::KeyPair::generate_ed25519().unwrap();

    // Serialize private key to OpenSSH PEM format
    let mut private_pem_buf = Vec::new();
    russh_keys::encode_pkcs8_pem(&key, &mut private_pem_buf)?;
    let private_pem = String::from_utf8(private_pem_buf)?;

    // Get public key in OpenSSH format
    let public_key = format!("ssh-ed25519 {} tap-relay", key.public_key_base64());

    // Encrypt and store
    let encrypted = crate::auth::encrypt(master_key, private_pem.as_bytes())?;
    let id = uuid::Uuid::new_v4().to_string();
    db.store_key(&id, "relay", &encrypted, &public_key, "ed25519")?;

    // Also write public key to a file for easy access
    let pubkey_path = config.data_dir().join("relay_key.pub");
    std::fs::write(&pubkey_path, &public_key)?;

    tracing::info!("Relay SSH key generated: {}", &public_key[..40.min(public_key.len())]);

    Ok(())
}

/// Background task: ping all servers every N seconds
pub async fn health_loop(state: Arc<AppState>) {
    let interval = Duration::from_secs(state.config.health.ping_interval_seconds);

    if !state.config.health.enabled {
        tracing::info!("Health pings disabled");
        return;
    }

    loop {
        sleep(interval).await;

        let servers = match state.db.list_all_servers() {
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
