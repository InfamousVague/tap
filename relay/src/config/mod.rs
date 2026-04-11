use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Deserialize)]
pub struct RelayConfig {
    #[serde(default)]
    pub server: ServerConfig,
    #[serde(default)]
    pub tls: TlsConfig,
    #[serde(default)]
    pub ssh: SshConfig,
    #[serde(default)]
    pub health: HealthConfig,
    #[serde(default)]
    pub audit: AuditConfig,
    #[serde(default)]
    pub notifications: NotificationsConfig,
    #[serde(default)]
    pub import: ImportConfig,

    #[serde(skip)]
    config_path: Option<PathBuf>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServerConfig {
    #[serde(default = "default_host")]
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
    #[serde(default = "default_data_dir")]
    pub data_dir: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TlsConfig {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub auto_cert: bool,
    pub domain: Option<String>,
    pub cert_path: Option<String>,
    pub key_path: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SshConfig {
    #[serde(default = "default_max_idle")]
    pub max_idle_seconds: u64,
    #[serde(default = "default_max_connections")]
    pub max_connections_per_server: usize,
    #[serde(default = "default_timeout")]
    pub default_timeout_seconds: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct HealthConfig {
    #[serde(default = "default_ping_interval")]
    pub ping_interval_seconds: u64,
    #[serde(default = "default_true")]
    pub enabled: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct AuditConfig {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default = "default_retention")]
    pub retention_days: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NotificationsConfig {
    #[serde(default)]
    pub apns_enabled: bool,
    pub apns_key_path: Option<String>,
    pub apns_key_id: Option<String>,
    pub apns_team_id: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ImportConfig {
    #[serde(default = "default_true")]
    pub auto_import_ssh_config: bool,
}

// Defaults
fn default_host() -> String { "0.0.0.0".into() }
fn default_port() -> u16 { 8443 }
fn default_data_dir() -> String {
    dirs().join("data").to_string_lossy().into_owned()
}
fn default_max_idle() -> u64 { 300 }
fn default_max_connections() -> usize { 3 }
fn default_timeout() -> u64 { 30 }
fn default_ping_interval() -> u64 { 30 }
fn default_retention() -> u32 { 90 }
fn default_true() -> bool { true }

fn dirs() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home).join(".tap")
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            host: default_host(),
            port: default_port(),
            data_dir: default_data_dir(),
        }
    }
}

impl Default for TlsConfig {
    fn default() -> Self {
        Self { enabled: false, auto_cert: false, domain: None, cert_path: None, key_path: None }
    }
}

impl Default for SshConfig {
    fn default() -> Self {
        Self {
            max_idle_seconds: default_max_idle(),
            max_connections_per_server: default_max_connections(),
            default_timeout_seconds: default_timeout(),
        }
    }
}

impl Default for HealthConfig {
    fn default() -> Self {
        Self { ping_interval_seconds: default_ping_interval(), enabled: true }
    }
}

impl Default for AuditConfig {
    fn default() -> Self {
        Self { enabled: false, retention_days: default_retention() }
    }
}

impl Default for NotificationsConfig {
    fn default() -> Self {
        Self { apns_enabled: false, apns_key_path: None, apns_key_id: None, apns_team_id: None }
    }
}

impl Default for ImportConfig {
    fn default() -> Self {
        Self { auto_import_ssh_config: true }
    }
}

impl RelayConfig {
    pub fn load() -> anyhow::Result<Self> {
        let candidates = vec![
            PathBuf::from("/etc/tap/relay.toml"),
            dirs().join("relay.toml"),
            PathBuf::from("relay.toml"),
        ];

        for path in &candidates {
            if path.exists() {
                let content = std::fs::read_to_string(path)?;
                let mut config: RelayConfig = toml::from_str(&content)?;
                config.config_path = Some(path.clone());
                return Ok(config);
            }
        }

        // No config file found — use defaults
        tracing::info!("No relay.toml found, using defaults");
        Ok(Self::default())
    }

    pub fn resolved_path(&self) -> Option<&Path> {
        self.config_path.as_deref()
    }

    pub fn data_dir(&self) -> PathBuf {
        PathBuf::from(&self.server.data_dir)
    }
}

impl Default for RelayConfig {
    fn default() -> Self {
        Self {
            server: ServerConfig::default(),
            tls: TlsConfig::default(),
            ssh: SshConfig::default(),
            health: HealthConfig::default(),
            audit: AuditConfig::default(),
            notifications: NotificationsConfig::default(),
            import: ImportConfig::default(),
            config_path: None,
        }
    }
}
