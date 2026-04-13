use axum::{
    extract::{Extension, Path, State},
    http::{StatusCode, header},
    response::{IntoResponse, Response},
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use russh::*;
use russh::client;
use russh_keys::key;

use crate::AppState;
use crate::auth::middleware::UserId;
use crate::db::{NewServer, NewCommand};

/// POST /setup/token — generate a one-time setup token (requires auth).
/// Returns a token and the curl command to run on target servers.
pub async fn create_setup_token(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let token: String = (0..32)
        .map(|_| {
            let idx: u8 = rand::random::<u8>() % 62;
            (match idx {
                0..=9 => b'0' + idx,
                10..=35 => b'a' + idx - 10,
                _ => b'A' + idx - 36,
            }) as char
        })
        .collect();

    // Store with 10-minute expiry, linked to user
    let id = uuid::Uuid::new_v4().to_string();
    let expires = chrono::Utc::now() + chrono::Duration::minutes(10);
    state.db.store_setup_token(&id, &user.0, &token, &expires.to_rfc3339())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let relay_url = "https://tap.mattssoftware.com";
    let command = format!("curl -sSf {}/connect/{} | bash", relay_url, token);

    tracing::info!("Setup token created (expires in 10m)");

    Ok(Json(serde_json::json!({
        "token": token,
        "command": command,
        "expires": expires.to_rfc3339(),
    })))
}

/// GET /setup/install/:token — serves the bash install script (public, no auth).
pub async fn install_script(
    State(state): State<Arc<AppState>>,
    Path(token): Path<String>,
) -> Result<Response, StatusCode> {
    // Validate the setup token
    let _token_id = state.db.validate_setup_token(&token)
        .map_err(|e| {
            tracing::error!("Setup token validation error: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?
        .ok_or_else(|| {
            tracing::warn!("Setup token not found or expired: {}", &token[..8.min(token.len())]);
            StatusCode::NOT_FOUND
        })?;

    // Get relay's public key
    let relay_pubkey = get_relay_pubkey(&state)?;

    let relay_url = "https://tap.mattssoftware.com";

    let script = format!(r#"#!/usr/bin/env bash
set -euo pipefail

# ── Tap Server Setup ────────────────────────────────
# This script connects this server to your Tap account.

RELAY_URL="{relay_url}"
SETUP_TOKEN="{token}"
RELAY_PUBKEY="{relay_pubkey}"

echo ""
echo "  ┌────────────────────────────────────────┐"
echo "  │        Tap — Server Setup               │"
echo "  └────────────────────────────────────────┘"
echo ""

# 1. Install relay's SSH public key
echo "── Installing SSH key..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

if grep -qF "$RELAY_PUBKEY" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "   Key already installed."
else
    echo "$RELAY_PUBKEY" >> ~/.ssh/authorized_keys
    echo "   Key installed."
fi

# 2. Detect server info
HOSTNAME=$(hostname -f 2>/dev/null || hostname)
IP=$(curl -sf https://api.ipify.org 2>/dev/null || echo "$HOSTNAME")
USER=$(whoami)
PORT=${{SSH_CONNECTION##* }}
[ -z "$PORT" ] && PORT=22

echo "── Detected: $USER@$IP:$PORT ($HOSTNAME)"

# 3. Look for .tap.json config
COMMANDS='[]'
SERVER_NAME=""
TAP_CONFIG=""
for f in .tap.json ~/tap.json /etc/tap.json; do
    if [ -f "$f" ]; then
        TAP_CONFIG="$f"
        break
    fi
done

if [ -n "$TAP_CONFIG" ]; then
    echo "── Found config: $TAP_CONFIG"
    if command -v python3 &>/dev/null; then
        # Extract commands and optional name from config
        COMMANDS=$(python3 -c "
import json, sys
with open('$TAP_CONFIG') as f:
    data = json.load(f)
cmds = data.get('commands', [])
print(json.dumps(cmds))
" 2>/dev/null || echo "[]")
        SERVER_NAME=$(python3 -c "
import json
with open('$TAP_CONFIG') as f:
    data = json.load(f)
print(data.get('name', ''))
" 2>/dev/null || echo "")
    elif command -v jq &>/dev/null; then
        COMMANDS=$(jq '.commands // []' "$TAP_CONFIG" 2>/dev/null || echo "[]")
        SERVER_NAME=$(jq -r '.name // ""' "$TAP_CONFIG" 2>/dev/null || echo "")
    else
        echo "   Warning: No jq or python3 — can't parse .tap.json, importing server only."
    fi
    CMD_COUNT=$(echo "$COMMANDS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    echo "   Found $CMD_COUNT commands."
else
    echo "── No .tap.json found (server will be added with no commands)."
    echo "   Create one later: https://tap.mattssoftware.com/docs/tap-json"
fi

# Use config name, fall back to hostname
[ -z "$SERVER_NAME" ] && SERVER_NAME="$HOSTNAME"
echo "── Server name: $SERVER_NAME"

# 4. Register with relay
echo "── Registering with Tap relay..."
PAYLOAD=$(echo "$COMMANDS" | python3 -c "
import json, sys
cmds = json.load(sys.stdin)
data = {{
    'name': '$SERVER_NAME',
    'host': '$IP',
    'port': int('$PORT'),
    'user': '$USER',
    'commands': cmds
}}
print(json.dumps(data))
" 2>/dev/null)

if [ -z "$PAYLOAD" ]; then
    # Fallback without python
    PAYLOAD='{{"name":"'"$HOSTNAME"'","host":"'"$IP"'","port":'"$PORT"',"user":"'"$USER"'","commands":[]}}'
fi

RESULT=$(curl -sf -X POST "$RELAY_URL/setup/register/$SETUP_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "$PAYLOAD")

if [ $? -eq 0 ]; then
    echo ""
    echo "  ┌────────────────────────────────────────┐"
    echo "  │  ✓ Server connected to Tap!             │"
    echo "  │                                         │"
    echo "  │  Open the Tap app on your phone or      │"
    echo "  │  watch and pull to refresh.              │"
    echo "  └────────────────────────────────────────┘"
    echo ""
else
    echo ""
    echo "  ✗ Registration failed. Check your setup token."
    echo ""
    exit 1
fi
"#, relay_url = relay_url, token = token, relay_pubkey = relay_pubkey);

    Ok((
        [(header::CONTENT_TYPE, "text/plain; charset=utf-8")],
        script,
    ).into_response())
}

/// POST /setup/register/:token — called by the install script to register a server.
pub async fn register_server(
    State(state): State<Arc<AppState>>,
    Path(token): Path<String>,
    Json(body): Json<RegisterRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    // Validate and consume the setup token — returns (token_id, user_id)
    let (_token_id, user_id) = state.db.consume_setup_token(&token)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::UNAUTHORIZED)?;

    // Get the relay key ID so the server uses it for SSH
    let relay_key_id = state.db.find_key_by_label("relay")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or_else(|| {
            tracing::error!("Relay SSH key not found");
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    // Create the server under the user who generated the setup token
    let new_server = NewServer {
        name: body.name.clone(),
        host: body.host.clone(),
        port: body.port.unwrap_or(22),
        user: body.user.clone().unwrap_or_else(|| "root".to_string()),
        key_id: Some(relay_key_id),
        sort_order: 0,
    };

    let server_id = state.db.create_server(&new_server, &user_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Create commands if provided
    let mut commands_created = 0;
    for (i, cmd) in body.commands.iter().enumerate() {
        let new_cmd = NewCommand {
            server_id: server_id.clone(),
            label: cmd.label.clone(),
            command: cmd.command.clone(),
            confirm: cmd.confirm.unwrap_or(false),
            timeout_sec: cmd.timeout_sec.unwrap_or(30),
            sort_order: cmd.sort_order.unwrap_or(i as i32),
            pinned: cmd.pinned.unwrap_or(false),
        };
        state.db.create_command(&new_cmd)
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
        commands_created += 1;
    }

    tracing::info!(
        "Server registered via setup: {} ({}@{}:{}) with {} commands",
        body.name, body.user.as_deref().unwrap_or("root"), body.host, body.port.unwrap_or(22), commands_created
    );

    Ok(Json(serde_json::json!({
        "server_id": server_id,
        "commands_created": commands_created,
    })))
}

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub name: String,
    pub host: String,
    pub port: Option<u16>,
    pub user: Option<String>,
    #[serde(default)]
    pub commands: Vec<CommandEntry>,
}

#[derive(Deserialize)]
pub struct CommandEntry {
    pub label: String,
    pub command: String,
    pub confirm: Option<bool>,
    pub timeout_sec: Option<u32>,
    pub sort_order: Option<i32>,
    pub pinned: Option<bool>,
}

fn get_relay_pubkey(state: &AppState) -> Result<String, StatusCode> {
    let key_id = state.db.find_key_by_label("relay")
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    let key = state.db.get_encrypted_key(&key_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    Ok(key.public_key)
}

/// GET /setup/pubkey — public endpoint, returns relay's SSH public key.
pub async fn pubkey(
    State(state): State<Arc<AppState>>,
) -> Result<String, StatusCode> {
    get_relay_pubkey(&state)
}

// ── Provision endpoint ────────────────────────────────────────────────────

#[derive(Deserialize)]
pub struct ProvisionRequest {
    pub name: String,
    pub host: String,
    #[serde(default = "default_provision_port")]
    pub port: u16,
    pub username: String,
    pub password: String,
    #[serde(default)]
    pub commands: Vec<CommandEntry>,
}

fn default_provision_port() -> u16 { 22 }

/// Minimal SSH handler for the provision password-auth connection.
struct ProvisionSshHandler;

#[async_trait::async_trait]
impl client::Handler for ProvisionSshHandler {
    type Error = anyhow::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &key::PublicKey,
    ) -> Result<bool, Self::Error> {
        Ok(true)
    }
}

/// POST /setup/provision — automated server provisioning via SSH password.
///
/// Connects with password, installs the relay's SSH public key, creates the
/// server record and optional commands, then verifies key-based connectivity.
pub async fn provision_server(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
    Json(body): Json<ProvisionRequest>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    // Helper to build JSON error responses
    let err = |status: StatusCode, msg: &str| -> (StatusCode, Json<serde_json::Value>) {
        (status, Json(serde_json::json!({"error": msg})))
    };

    // 1. Get relay key metadata (public key + ID)
    let relay_key_id = state.db.find_key_by_label("relay")
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Database error"))?
        .ok_or_else(|| {
            tracing::error!("Relay SSH key not found in DB");
            err(StatusCode::INTERNAL_SERVER_ERROR, "Relay SSH key not configured")
        })?;

    let encrypted_key = state.db.get_encrypted_key(&relay_key_id)
        .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Database error"))?
        .ok_or_else(|| {
            tracing::error!("Relay encrypted key not found");
            err(StatusCode::INTERNAL_SERVER_ERROR, "Relay key not found")
        })?;

    let relay_pubkey = &encrypted_key.public_key;

    // 2. Connect via SSH using password authentication
    let config = Arc::new(client::Config::default());
    let addr = format!("{}:{}", body.host, body.port);
    let handler = ProvisionSshHandler;

    let mut handle = client::connect(config, &*addr, handler)
        .await
        .map_err(|e| {
            tracing::error!("SSH connect failed to {}: {}", addr, e);
            err(StatusCode::BAD_GATEWAY, &format!("SSH connection failed: {}", e))
        })?;

    let authenticated = handle
        .authenticate_password(&body.username, &body.password)
        .await
        .map_err(|e| {
            tracing::error!("SSH password auth error: {}", e);
            err(StatusCode::BAD_GATEWAY, &format!("SSH auth error: {}", e))
        })?;

    if !authenticated {
        tracing::warn!("SSH password auth rejected for {}@{}", body.username, body.host);
        return Err(err(StatusCode::UNAUTHORIZED, "SSH password rejected — check username and password"));
    }

    // 3. Install relay public key in authorized_keys
    let install_script = format!(
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
         touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && \
         grep -qF '{pubkey}' ~/.ssh/authorized_keys 2>/dev/null || \
         echo '{pubkey}' >> ~/.ssh/authorized_keys",
        pubkey = relay_pubkey,
    );

    let mut channel = handle.channel_open_session().await.map_err(|e| {
        tracing::error!("Failed to open SSH channel: {}", e);
        err(StatusCode::BAD_GATEWAY, &format!("SSH channel failed: {}", e))
    })?;

    channel.exec(true, install_script.as_bytes()).await.map_err(|e| {
        tracing::error!("Failed to exec key install: {}", e);
        err(StatusCode::BAD_GATEWAY, &format!("Key install failed: {}", e))
    })?;

    // Wait for command to finish
    let mut exit_code: i32 = -1;
    let mut stderr_out = String::new();
    let mut got_eof = false;
    loop {
        match channel.wait().await {
            Some(ChannelMsg::ExitStatus { exit_status }) => {
                exit_code = exit_status as i32;
                if got_eof { break; }
            }
            Some(ChannelMsg::ExtendedData { data, ext }) => {
                if ext == 1 {
                    stderr_out.push_str(&String::from_utf8_lossy(&data));
                }
            }
            Some(ChannelMsg::Eof) => {
                got_eof = true;
                if exit_code != -1 { break; }
            }
            None => break,
            _ => {}
        }
    }

    if exit_code != 0 {
        tracing::error!("Key install exited with {}: {}", exit_code, stderr_out);
        return Err(err(StatusCode::BAD_GATEWAY, &format!("Key install failed (exit {}): {}", exit_code, stderr_out)));
    }

    // Done with password connection
    drop(handle);

    // 4. Create server record
    let new_server = NewServer {
        name: body.name.clone(),
        host: body.host.clone(),
        port: body.port,
        user: body.username.clone(),
        key_id: Some(relay_key_id.clone()),
        sort_order: 0,
    };

    let server_id = state.db.create_server(&new_server, &user.0)
        .map_err(|e| {
            tracing::error!("Failed to create server: {}", e);
            err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to create server record")
        })?;

    // 5. Create commands if provided
    let mut commands_created = 0;
    for (i, cmd) in body.commands.iter().enumerate() {
        let new_cmd = NewCommand {
            server_id: server_id.clone(),
            label: cmd.label.clone(),
            command: cmd.command.clone(),
            confirm: cmd.confirm.unwrap_or(false),
            timeout_sec: cmd.timeout_sec.unwrap_or(30),
            sort_order: cmd.sort_order.unwrap_or(i as i32),
            pinned: cmd.pinned.unwrap_or(false),
        };
        state.db.create_command(&new_cmd)
            .map_err(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "Failed to create command"))?;
        commands_created += 1;
    }

    // 6. Verify key-based connection (ping via the SSH pool)
    let connection_verified = {
        let mut pool = state.ssh_pool.lock().await;
        pool.ping(&server_id, &body.host, body.port, &body.username, &state)
            .await
            .is_some()
    };

    tracing::info!(
        "Server provisioned: {} ({}@{}:{}) — {} commands, verified={}",
        body.name, body.username, body.host, body.port, commands_created, connection_verified
    );

    // 7. Return result
    Ok(Json(serde_json::json!({
        "server_id": server_id,
        "commands_created": commands_created,
        "connection_verified": connection_verified,
    })))
}
