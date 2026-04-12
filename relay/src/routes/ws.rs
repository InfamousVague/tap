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
}

/// WebSocket endpoint for streaming command output line-by-line
pub async fn ws_exec(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> Response {
    ws.on_upgrade(move |socket| handle_ws_exec(socket, state))
}

async fn handle_ws_exec(mut socket: WebSocket, state: Arc<AppState>) {
    // First message should be the exec request (JSON)
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

    // Look up server
    let server = match state.db.get_server(&params.server_id) {
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

    // Send output lines
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

    // Send completion
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
