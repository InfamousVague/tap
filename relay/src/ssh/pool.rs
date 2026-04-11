use std::collections::HashMap;
use std::time::{Duration, Instant};

use crate::config::SshConfig;
use crate::db::ExecResult;
use crate::AppState;

/// A pooled SSH connection handle
struct PooledConnection {
    // In the real implementation, this holds a russh::client::Handle
    // For now we track metadata for the pool logic
    server_id: String,
    last_used: Instant,
    connected: bool,
}

/// SSH connection pool — reuses connections to avoid reconnection overhead
pub struct SshPool {
    connections: HashMap<String, Vec<PooledConnection>>,
    max_idle_sec: u64,
    max_per_server: usize,
    default_timeout: u64,
}

impl SshPool {
    pub fn new(config: &SshConfig) -> Self {
        Self {
            connections: HashMap::new(),
            max_idle_sec: config.max_idle_seconds,
            max_per_server: config.max_connections_per_server,
            default_timeout: config.default_timeout_seconds,
        }
    }

    /// Execute a command on a server, returning the result
    pub async fn execute(
        &mut self,
        server_id: &str,
        host: &str,
        port: u16,
        user: &str,
        command: &str,
        timeout_sec: Option<u64>,
        state: &AppState,
    ) -> ExecResult {
        let timeout = Duration::from_secs(timeout_sec.unwrap_or(self.default_timeout));
        let start = Instant::now();

        // Get or create connection
        match self.connect_and_exec(server_id, host, port, user, command, timeout, state).await {
            Ok((exit_code, stdout, stderr)) => {
                let duration_ms = start.elapsed().as_millis() as u64;
                ExecResult {
                    status: if exit_code == 0 { "success".into() } else { "failed".into() },
                    exit_code: Some(exit_code),
                    stdout,
                    stderr,
                    duration_ms,
                }
            }
            Err(e) => {
                let duration_ms = start.elapsed().as_millis() as u64;
                ExecResult {
                    status: "error".into(),
                    exit_code: None,
                    stdout: String::new(),
                    stderr: e.to_string(),
                    duration_ms,
                }
            }
        }
    }

    /// Ping a server — returns latency in ms if reachable
    pub async fn ping(
        &mut self,
        server_id: &str,
        host: &str,
        port: u16,
        user: &str,
        state: &AppState,
    ) -> Option<u32> {
        let start = Instant::now();
        let result = self.connect_and_exec(
            server_id, host, port, user, "echo pong",
            Duration::from_secs(10), state,
        ).await;

        match result {
            Ok(_) => Some(start.elapsed().as_millis() as u32),
            Err(_) => None,
        }
    }

    /// Remove idle connections that have exceeded max_idle_sec
    pub fn cleanup_idle(&mut self) {
        let max_idle = Duration::from_secs(self.max_idle_sec);
        let now = Instant::now();

        self.connections.retain(|server_id, conns| {
            let before = conns.len();
            conns.retain(|c| now.duration_since(c.last_used) < max_idle);
            let removed = before - conns.len();
            if removed > 0 {
                tracing::debug!("Cleaned up {} idle connections for {}", removed, server_id);
            }
            !conns.is_empty()
        });
    }

    /// Internal: connect to server and execute command
    async fn connect_and_exec(
        &mut self,
        server_id: &str,
        host: &str,
        port: u16,
        user: &str,
        command: &str,
        timeout: Duration,
        state: &AppState,
    ) -> anyhow::Result<(i32, String, String)> {
        // Get the SSH key for this server
        let server = state.db.get_server(server_id)?
            .ok_or_else(|| anyhow::anyhow!("Server not found"))?;

        let key_id = server.key_id
            .ok_or_else(|| anyhow::anyhow!("No SSH key configured for server"))?;

        let encrypted_key = state.db.get_encrypted_key(&key_id)?
            .ok_or_else(|| anyhow::anyhow!("SSH key not found"))?;

        let master_key = state.master_key
            .ok_or_else(|| anyhow::anyhow!("Master key not available"))?;

        // Decrypt the SSH private key
        let private_key_bytes = crate::auth::decrypt(&master_key, &encrypted_key.encrypted_key)?;
        let _private_key_pem = String::from_utf8(private_key_bytes)?;

        // TODO: Use russh to establish connection and execute command
        // For now, return a placeholder indicating the infrastructure is ready
        // The actual russh integration will be:
        //
        // let key_pair = russh_keys::decode_secret_key(&private_key_pem, None)?;
        // let config = Arc::new(russh::client::Config::default());
        // let mut session = russh::client::connect(config, (host, port), handler).await?;
        // session.authenticate_publickey(user, Arc::new(key_pair)).await?;
        // let mut channel = session.channel_open_session().await?;
        // channel.exec(true, command).await?;
        // ... read stdout/stderr with timeout ...

        tracing::debug!("Would execute '{}' on {}@{}:{}", command, user, host, port);

        // Mark connection as used
        let conns = self.connections.entry(server_id.to_string()).or_default();
        if conns.is_empty() {
            conns.push(PooledConnection {
                server_id: server_id.to_string(),
                last_used: Instant::now(),
                connected: true,
            });
        } else {
            conns[0].last_used = Instant::now();
        }

        // Placeholder - actual SSH execution will replace this
        Err(anyhow::anyhow!("SSH execution not yet implemented — infrastructure ready, pending russh integration"))
    }
}
