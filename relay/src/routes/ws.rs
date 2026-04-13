use axum::{
    extract::{State, WebSocketUpgrade, ws::{Message, WebSocket}},
    response::Response,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::AppState;

#[derive(Deserialize)]
pub struct WsExecParams {
    pub server_id: String,
    pub command: String,
    /// Auth token for WebSocket (since we can't use middleware)
    pub token: Option<String>,
}

/// WebSocket endpoint for streaming command output line-by-line
pub async fn ws_exec(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> Response {
    ws.on_upgrade(move |socket| handle_ws_exec(socket, state))
}

async fn handle_ws_exec(mut socket: WebSocket, state: Arc<AppState>) {
    // First message should be the exec request (JSON) with auth token
    let params: WsExecParams = match socket.recv().await {
        Some(Ok(Message::Text(text))) => {
            match serde_json::from_str(&text) {
                Ok(p) => p,
                Err(e) => {
                    let _ = socket.send(Message::Text(
                        serde_json::json!({"error": format!("Invalid request: {}", e)}).to_string()
                    )).await;
                    return;
                }
            }
        }
        _ => return,
    };

    // Authenticate the WebSocket request
    let user_id = match &params.token {
        Some(token) => {
            match authenticate_ws_token(&state, token) {
                Some(uid) => uid,
                None => {
                    let _ = socket.send(Message::Text(
                        serde_json::json!({"error": "Unauthorized"}).to_string()
                    )).await;
                    return;
                }
            }
        }
        None => {
            let _ = socket.send(Message::Text(
                serde_json::json!({"error": "Missing token"}).to_string()
            )).await;
            return;
        }
    };

    // Look up server (user-scoped)
    let server = match state.db.get_server(&params.server_id, &user_id) {
        Ok(Some(s)) => s,
        _ => {
            let _ = socket.send(Message::Text(
                serde_json::json!({"error": "Server not found"}).to_string()
            )).await;
            return;
        }
    };

    // Send start message
    let _ = socket.send(Message::Text(
        serde_json::json!({"type": "start", "server": server.name, "command": params.command}).to_string()
    )).await;

    // Execute and stream output
    let mut pool = state.ssh_pool.lock().await;
    let result = pool.execute(
        &server.id,
        &server.host,
        server.port,
        &server.user,
        &params.command,
        None,
        &state,
    ).await;

    for line in result.stdout.lines() {
        let _ = socket.send(Message::Text(
            serde_json::json!({"type": "stdout", "data": line}).to_string()
        )).await;
    }

    for line in result.stderr.lines() {
        let _ = socket.send(Message::Text(
            serde_json::json!({"type": "stderr", "data": line}).to_string()
        )).await;
    }

    let _ = socket.send(Message::Text(
        serde_json::json!({
            "type": "done",
            "exit_code": result.exit_code,
            "duration_ms": result.duration_ms,
            "status": result.status,
        }).to_string()
    )).await;

    let _ = socket.close().await;
}

fn authenticate_ws_token(state: &AppState, token: &str) -> Option<String> {
    let hashes = state.db.all_token_hashes().ok()?;
    for (_id, user_id, hash) in &hashes {
        if crate::auth::verify_token(token, hash) {
            return Some(user_id.clone());
        }
    }
    None
}
