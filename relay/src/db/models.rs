use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Server {
    pub id: String,
    pub name: String,
    pub host: String,
    pub port: u16,
    pub user: String,
    pub key_id: Option<String>,
    pub sort_order: i32,
    pub status: Option<String>,
    pub latency_ms: Option<u32>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NewServer {
    pub name: String,
    pub host: String,
    #[serde(default = "default_port")]
    pub port: u16,
    pub user: String,
    pub key_id: Option<String>,
    #[serde(default)]
    pub sort_order: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Command {
    pub id: String,
    pub server_id: String,
    pub label: String,
    pub command: String,
    pub confirm: bool,
    pub timeout_sec: u32,
    pub sort_order: i32,
    pub pinned: bool,
    pub created_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NewCommand {
    pub server_id: String,
    pub label: String,
    pub command: String,
    #[serde(default = "default_true")]
    pub confirm: bool,
    #[serde(default = "default_timeout")]
    pub timeout_sec: u32,
    #[serde(default)]
    pub sort_order: i32,
    #[serde(default)]
    pub pinned: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Suite {
    pub id: String,
    pub server_id: String,
    pub label: String,
    pub created_at: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NewSuite {
    pub server_id: String,
    pub label: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SuiteStep {
    pub id: String,
    pub suite_id: String,
    pub command_id: String,
    pub step_order: i32,
    pub continue_on_fail: bool,
}

#[derive(Debug, Clone, Serialize)]
pub struct SshKeyMeta {
    pub id: String,
    pub label: String,
    pub public_key: String,
    pub key_type: String,
    pub created_at: String,
}

#[derive(Debug, Clone)]
pub struct EncryptedKey {
    pub id: String,
    pub encrypted_key: Vec<u8>,
    pub public_key: String,
    pub key_type: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ApiToken {
    pub id: String,
    pub label: String,
    pub device_type: Option<String>,
    pub last_used: Option<String>,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecEntry {
    pub id: String,
    pub server_id: String,
    pub command_id: Option<String>,
    pub suite_id: Option<String>,
    pub command_text: Option<String>,
    pub exit_code: Option<i32>,
    pub stdout: Option<String>,
    pub stderr: Option<String>,
    pub duration_ms: Option<u32>,
    pub device: Option<String>,
    pub created_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecRequest {
    pub server_id: String,
    pub command_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecAdhocRequest {
    pub server_id: String,
    pub command: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ExecResult {
    pub status: String,
    pub exit_code: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub duration_ms: u64,
}

fn default_port() -> u16 { 22 }
fn default_true() -> bool { true }
fn default_timeout() -> u32 { 30 }
