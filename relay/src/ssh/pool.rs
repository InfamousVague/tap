use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::io::AsyncReadExt;

use russh::*;
use russh::client;
use russh_keys::key;

use crate::config::SshConfig;
use crate::db::ExecResult;
use crate::AppState;

/// SSH connection pool — reuses connections to avoid reconnection overhead
pub struct SshPool {
    connections: HashMap<String, CachedSession>,
    max_idle_sec: u64,
    max_per_server: usize,
    default_timeout: u64,
}

struct CachedSession {
    handle: client::Handle<SshHandler>,
    last_used: Instant,
}

/// Minimal SSH client handler
struct SshHandler;

#[async_trait::async_trait]
impl client::Handler for SshHandler {
    type Error = anyhow::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &key::PublicKey,
    ) -> Result<bool, Self::Error> {
        // Accept all server keys (like ssh -o StrictHostKeyChecking=no)
        // In production, you'd verify against known_hosts
        Ok(true)
    }
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

        self.connections.retain(|server_id, session| {
            let idle = now.duration_since(session.last_used) >= max_idle;
            if idle {
                tracing::debug!("Cleaned up idle connection for {}", server_id);
            }
            !idle
        });
    }

    /// Get or create an SSH connection, then execute a command
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
        let server = state.db.get_server_system(server_id)?
            .ok_or_else(|| anyhow::anyhow!("Server not found"))?;

        let key_id = server.key_id
            .ok_or_else(|| anyhow::anyhow!("No SSH key configured for server"))?;

        let encrypted_key = state.db.get_encrypted_key(&key_id)?
            .ok_or_else(|| anyhow::anyhow!("SSH key not found"))?;

        let master_key = state.master_key
            .ok_or_else(|| anyhow::anyhow!("Master key not available"))?;

        // Decrypt the SSH private key
        let private_key_bytes = crate::auth::decrypt(&master_key, &encrypted_key.encrypted_key)?;
        let private_key_pem = String::from_utf8(private_key_bytes)?;

        // Try to reuse cached connection, or create new one
        let needs_new_connection = match self.connections.get(server_id) {
            Some(cached) => {
                // Check if connection is stale
                Instant::now().duration_since(cached.last_used) > Duration::from_secs(self.max_idle_sec)
            }
            None => true,
        };

        if needs_new_connection {
            // Parse the private key
            let key_pair = russh_keys::decode_secret_key(&private_key_pem, None)?;

            // Connect
            let config = Arc::new(client::Config::default());

            let addr = format!("{}:{}", host, port);
            let handler = SshHandler;
            let mut handle = client::connect(config, &*addr, handler).await?;

            // Authenticate
            let authenticated = handle
                .authenticate_publickey(user, Arc::new(key_pair))
                .await?;

            if !authenticated {
                anyhow::bail!("SSH authentication failed for {}@{}", user, host);
            }

            self.connections.insert(server_id.to_string(), CachedSession {
                handle,
                last_used: Instant::now(),
            });
        }

        // Execute command on the connection
        let session = self.connections.get_mut(server_id).unwrap();
        session.last_used = Instant::now();

        let mut channel = session.handle.channel_open_session().await?;
        channel.exec(true, command.as_bytes()).await?;

        // Collect output with timeout
        let mut stdout = String::new();
        let mut stderr = String::new();
        let mut exit_code: i32 = -1;
        let mut got_eof = false;

        let result = tokio::time::timeout(timeout, async {
            loop {
                match channel.wait().await {
                    Some(ChannelMsg::Data { data }) => {
                        stdout.push_str(&String::from_utf8_lossy(&data));
                    }
                    Some(ChannelMsg::ExtendedData { data, ext }) => {
                        if ext == 1 {
                            stderr.push_str(&String::from_utf8_lossy(&data));
                        }
                    }
                    Some(ChannelMsg::ExitStatus { exit_status }) => {
                        exit_code = exit_status as i32;
                        if got_eof { break; }
                    }
                    Some(ChannelMsg::Eof) => {
                        got_eof = true;
                        if exit_code != -1 { break; }
                    }
                    None => break,
                    _ => {}
                }
            }
        }).await;

        if result.is_err() {
            // Timeout — kill the channel
            let _ = channel.close().await;
            // Remove stale connection
            self.connections.remove(server_id);
            anyhow::bail!("Command timed out after {:?}", timeout);
        }

        Ok((exit_code, stdout, stderr))
    }
}
