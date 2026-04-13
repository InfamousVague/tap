use axum::{
    extract::{Extension, State},
    http::StatusCode,
    Json,
};
use serde::Serialize;
use std::sync::Arc;

use crate::AppState;
use crate::auth::middleware::UserId;

#[derive(Serialize)]
pub struct ServerOverview {
    server_id: String,
    server_name: String,
    status: String,
    latency_ms: Option<u32>,
    os: Option<String>,
    kernel: Option<String>,
    uptime: Option<String>,
    load: Option<[f64; 3]>,
    disk: Option<DiskInfo>,
    memory: Option<MemoryInfo>,
    ip: Option<String>,
    docker_running: Option<u32>,
    docker_total: Option<u32>,
}

#[derive(Serialize)]
pub struct DiskInfo {
    total: String,
    used: String,
    available: String,
    use_percent: u32,
}

#[derive(Serialize)]
pub struct MemoryInfo {
    total_mb: u64,
    used_mb: u64,
    free_mb: u64,
    use_percent: u32,
}

const DIAGNOSTIC_CMD: &str = r#"uname -srm; cat /etc/os-release 2>/dev/null | grep -E '^(PRETTY_NAME|ID)=' | head -2; df -h / | tail -1; free -m 2>/dev/null | head -2; uptime; cat /proc/loadavg 2>/dev/null; hostname -I 2>/dev/null | awk '{print $1}'; docker ps --format '{{.Names}}:{{.Status}}' 2>/dev/null | head -10"#;

pub async fn get_overview(
    State(state): State<Arc<AppState>>,
    Extension(user): Extension<UserId>,
) -> Result<Json<Vec<ServerOverview>>, StatusCode> {
    let servers = state
        .db
        .list_servers(&user.0)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let mut results = Vec::with_capacity(servers.len());

    let mut pool = state.ssh_pool.lock().await;

    for server in &servers {
        let status = server
            .status
            .as_deref()
            .unwrap_or("unknown");

        if status == "down" {
            results.push(ServerOverview {
                server_id: server.id.clone(),
                server_name: server.name.clone(),
                status: "down".into(),
                latency_ms: server.latency_ms,
                os: None,
                kernel: None,
                uptime: None,
                load: None,
                disk: None,
                memory: None,
                ip: None,
                docker_running: None,
                docker_total: None,
            });
            continue;
        }

        let result = pool
            .execute(
                &server.id,
                &server.host,
                server.port,
                &server.user,
                DIAGNOSTIC_CMD,
                Some(10),
                &state,
            )
            .await;

        if result.exit_code.is_none() || result.stdout.is_empty() {
            results.push(ServerOverview {
                server_id: server.id.clone(),
                server_name: server.name.clone(),
                status: "down".into(),
                latency_ms: None,
                os: None,
                kernel: None,
                uptime: None,
                load: None,
                disk: None,
                memory: None,
                ip: None,
                docker_running: None,
                docker_total: None,
            });
            continue;
        }

        let overview = parse_overview(&server.id, &server.name, server.latency_ms, &result.stdout);
        results.push(overview);
    }

    Ok(Json(results))
}

fn parse_overview(
    server_id: &str,
    server_name: &str,
    latency_ms: Option<u32>,
    stdout: &str,
) -> ServerOverview {
    let lines: Vec<&str> = stdout.lines().collect();

    let kernel = lines.first().map(|s| s.to_string());

    // Parse PRETTY_NAME from os-release
    let os = lines.iter().find_map(|line| {
        line.strip_prefix("PRETTY_NAME=")
            .map(|v| v.trim_matches('"').to_string())
    });

    // Parse df output: filesystem size used avail use% mount
    let disk = lines.iter().find_map(|line| {
        let parts: Vec<&str> = line.split_whitespace().collect();
        // df output has 6 columns; use% column ends with '%'
        if parts.len() >= 5 {
            if let Some(pct_str) = parts.iter().find(|p| p.ends_with('%')) {
                let pct_idx = parts.iter().position(|p| p.ends_with('%'))?;
                if pct_idx >= 3 {
                    let use_pct = pct_str.trim_end_matches('%').parse::<u32>().ok()?;
                    return Some(DiskInfo {
                        total: parts[pct_idx - 3].to_string(),
                        used: parts[pct_idx - 2].to_string(),
                        available: parts[pct_idx - 1].to_string(),
                        use_percent: use_pct,
                    });
                }
            }
        }
        None
    });

    // Parse free -m output (second line is the data line with "Mem:" prefix)
    let memory = lines.iter().find_map(|line| {
        if line.starts_with("Mem:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 4 {
                let total = parts[1].parse::<u64>().ok()?;
                let used = parts[2].parse::<u64>().ok()?;
                let free = parts[3].parse::<u64>().ok()?;
                let use_pct = if total > 0 {
                    ((used as f64 / total as f64) * 100.0) as u32
                } else {
                    0
                };
                return Some(MemoryInfo {
                    total_mb: total,
                    used_mb: used,
                    free_mb: free,
                    use_percent: use_pct,
                });
            }
        }
        None
    });

    // Parse uptime line (contains "up" and "load average")
    let uptime = lines.iter().find_map(|line| {
        if line.contains("load average:") && line.contains(" up ") {
            if let Some(up_start) = line.find(" up ") {
                let after_up = &line[up_start + 4..];
                // Find "user" and work backward to find the user count + comma before it
                // Format: "1 day, 3:45, 2 users, load average: ..."
                if let Some(user_pos) = after_up.find("user") {
                    let before_user = &after_up[..user_pos];
                    // Split by comma, drop the last segment (user count), rejoin
                    let parts: Vec<&str> = before_user.split(',').collect();
                    if parts.len() >= 2 {
                        let uptime_parts = &parts[..parts.len() - 1];
                        return Some(uptime_parts.join(",").trim().to_string());
                    } else {
                        return Some(before_user.trim().to_string());
                    }
                }
            }
        }
        None
    });

    // Parse /proc/loadavg (e.g. "0.08 0.03 0.01 1/234 5678")
    let load = lines.iter().find_map(|line| {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 3 {
            let l1 = parts[0].parse::<f64>().ok()?;
            let l5 = parts[1].parse::<f64>().ok()?;
            let l15 = parts[2].parse::<f64>().ok()?;
            // Verify this looks like loadavg (contains a "/" in 4th field)
            if parts.len() >= 4 && parts[3].contains('/') {
                return Some([l1, l5, l15]);
            }
        }
        None
    });

    // Parse IP - line that looks like a bare IP address
    let ip = lines.iter().find_map(|line| {
        let trimmed = line.trim();
        // Simple check: starts with a digit, contains dots, no spaces, looks like an IP
        if !trimmed.is_empty()
            && !trimmed.contains(' ')
            && !trimmed.contains('/')
            && !trimmed.contains(':')
            && !trimmed.contains('=')
            && trimmed.chars().next().map_or(false, |c| c.is_ascii_digit())
            && trimmed.matches('.').count() == 3
        {
            // Validate each octet
            let valid = trimmed.split('.').all(|p| p.parse::<u8>().is_ok());
            if valid {
                return Some(trimmed.to_string());
            }
        }
        None
    });

    // Parse docker ps output (lines with "name:status" format containing "Up" or "Exited")
    let docker_lines: Vec<&str> = lines
        .iter()
        .filter(|line| {
            let l = line.trim();
            l.contains(':') && (l.contains("Up ") || l.contains("Exited"))
        })
        .copied()
        .collect();

    let (docker_running, docker_total) = if docker_lines.is_empty() {
        (None, None)
    } else {
        let total = docker_lines.len() as u32;
        let running = docker_lines
            .iter()
            .filter(|l| l.contains("Up "))
            .count() as u32;
        (Some(running), Some(total))
    };

    ServerOverview {
        server_id: server_id.to_string(),
        server_name: server_name.to_string(),
        status: "up".into(),
        latency_ms,
        os,
        kernel,
        uptime,
        load,
        disk,
        memory,
        ip,
        docker_running,
        docker_total,
    }
}
