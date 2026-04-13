use std::fs;
use std::path::PathBuf;

use crate::db::{Database, NewServer};

/// Parse ~/.ssh/config and import servers into the database
pub fn import_ssh_config(db: &Database, user_id: &str) -> anyhow::Result<usize> {
    let home = std::env::var("HOME")?;
    let config_path = PathBuf::from(&home).join(".ssh").join("config");

    if !config_path.exists() {
        return Ok(0);
    }

    let content = fs::read_to_string(&config_path)?;
    let servers = parse_ssh_config(&content);

    let mut count = 0;
    for server in servers {
        if server.host.is_empty() || server.host == "*" {
            continue;
        }
        db.create_server(&server, user_id)?;
        count += 1;
    }

    Ok(count)
}

/// Parse SSH config file content into NewServer entries
fn parse_ssh_config(content: &str) -> Vec<NewServer> {
    let mut servers = Vec::new();
    let mut current: Option<SshConfigEntry> = None;

    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        let (key, value) = match line.split_once(char::is_whitespace) {
            Some((k, v)) => (k.to_lowercase(), v.trim().to_string()),
            None => continue,
        };

        match key.as_str() {
            "host" => {
                // Save previous entry
                if let Some(entry) = current.take() {
                    if let Some(server) = entry.into_server() {
                        servers.push(server);
                    }
                }
                current = Some(SshConfigEntry {
                    name: value.clone(),
                    hostname: String::new(),
                    port: 22,
                    user: String::new(),
                    identity_file: None,
                });
            }
            "hostname" => {
                if let Some(ref mut entry) = current {
                    entry.hostname = value;
                }
            }
            "port" => {
                if let Some(ref mut entry) = current {
                    entry.port = value.parse().unwrap_or(22);
                }
            }
            "user" => {
                if let Some(ref mut entry) = current {
                    entry.user = value;
                }
            }
            "identityfile" => {
                if let Some(ref mut entry) = current {
                    entry.identity_file = Some(value);
                }
            }
            _ => {}
        }
    }

    // Don't forget the last entry
    if let Some(entry) = current {
        if let Some(server) = entry.into_server() {
            servers.push(server);
        }
    }

    servers
}

struct SshConfigEntry {
    name: String,
    hostname: String,
    port: u16,
    user: String,
    identity_file: Option<String>,
}

impl SshConfigEntry {
    fn into_server(self) -> Option<NewServer> {
        // Skip wildcard entries
        if self.name == "*" || self.name.contains('*') {
            return None;
        }

        let host = if self.hostname.is_empty() {
            self.name.clone()
        } else {
            self.hostname
        };

        let user = if self.user.is_empty() {
            std::env::var("USER").unwrap_or_else(|_| "root".into())
        } else {
            self.user
        };

        Some(NewServer {
            name: self.name,
            host,
            port: self.port,
            user,
            key_id: None, // Keys are imported separately
            sort_order: 0,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_ssh_config() {
        let config = r#"
Host prod-api
    HostName 10.0.1.50
    User deploy
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host staging
    HostName staging.example.com
    User ubuntu
    Port 2222

Host *
    ServerAliveInterval 60
"#;

        let servers = parse_ssh_config(config);
        assert_eq!(servers.len(), 2);
        assert_eq!(servers[0].name, "prod-api");
        assert_eq!(servers[0].host, "10.0.1.50");
        assert_eq!(servers[0].user, "deploy");
        assert_eq!(servers[0].port, 22);
        assert_eq!(servers[1].name, "staging");
        assert_eq!(servers[1].host, "staging.example.com");
        assert_eq!(servers[1].user, "ubuntu");
        assert_eq!(servers[1].port, 2222);
    }
}
