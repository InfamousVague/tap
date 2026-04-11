mod models;

pub use models::*;

use rusqlite::{Connection, params};
use std::path::Path;
use std::sync::Mutex;

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    pub fn open(data_dir: &Path) -> anyhow::Result<Self> {
        std::fs::create_dir_all(data_dir)?;
        let db_path = data_dir.join("tap.db");
        let conn = Connection::open(&db_path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;")?;
        Ok(Self { conn: Mutex::new(conn) })
    }

    pub fn run_migrations(&self) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(MIGRATIONS)?;
        Ok(())
    }

    // --- Servers ---

    pub fn server_count(&self) -> anyhow::Result<usize> {
        let conn = self.conn.lock().unwrap();
        let count: usize = conn.query_row("SELECT COUNT(*) FROM servers", [], |r| r.get(0))?;
        Ok(count)
    }

    pub fn list_servers(&self) -> anyhow::Result<Vec<Server>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, host, port, user, key_id, sort_order, status, latency_ms, created_at, updated_at FROM servers ORDER BY sort_order, name"
        )?;
        let servers = stmt.query_map([], |row| {
            Ok(Server {
                id: row.get(0)?,
                name: row.get(1)?,
                host: row.get(2)?,
                port: row.get(3)?,
                user: row.get(4)?,
                key_id: row.get(5)?,
                sort_order: row.get(6)?,
                status: row.get(7)?,
                latency_ms: row.get(8)?,
                created_at: row.get(9)?,
                updated_at: row.get(10)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(servers)
    }

    pub fn get_server(&self, id: &str) -> anyhow::Result<Option<Server>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, host, port, user, key_id, sort_order, status, latency_ms, created_at, updated_at FROM servers WHERE id = ?1"
        )?;
        let server = stmt.query_row(params![id], |row| {
            Ok(Server {
                id: row.get(0)?,
                name: row.get(1)?,
                host: row.get(2)?,
                port: row.get(3)?,
                user: row.get(4)?,
                key_id: row.get(5)?,
                sort_order: row.get(6)?,
                status: row.get(7)?,
                latency_ms: row.get(8)?,
                created_at: row.get(9)?,
                updated_at: row.get(10)?,
            })
        }).optional()?;
        Ok(server)
    }

    pub fn create_server(&self, server: &NewServer) -> anyhow::Result<String> {
        let conn = self.conn.lock().unwrap();
        let id = uuid::Uuid::new_v4().to_string();
        conn.execute(
            "INSERT INTO servers (id, name, host, port, user, key_id, sort_order) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![id, server.name, server.host, server.port, server.user, server.key_id, server.sort_order],
        )?;
        Ok(id)
    }

    pub fn update_server(&self, id: &str, server: &NewServer) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE servers SET name=?2, host=?3, port=?4, user=?5, key_id=?6, sort_order=?7, updated_at=datetime('now') WHERE id=?1",
            params![id, server.name, server.host, server.port, server.user, server.key_id, server.sort_order],
        )?;
        Ok(())
    }

    pub fn delete_server(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM servers WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn update_server_status(&self, id: &str, status: &str, latency_ms: Option<u32>) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE servers SET status=?2, latency_ms=?3, updated_at=datetime('now') WHERE id=?1",
            params![id, status, latency_ms],
        )?;
        Ok(())
    }

    // --- Commands ---

    pub fn list_commands(&self, server_id: &str) -> anyhow::Result<Vec<Command>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, server_id, label, command, confirm, timeout_sec, sort_order, pinned, created_at FROM commands WHERE server_id=?1 ORDER BY sort_order, label"
        )?;
        let commands = stmt.query_map(params![server_id], |row| {
            Ok(Command {
                id: row.get(0)?,
                server_id: row.get(1)?,
                label: row.get(2)?,
                command: row.get(3)?,
                confirm: row.get(4)?,
                timeout_sec: row.get(5)?,
                sort_order: row.get(6)?,
                pinned: row.get(7)?,
                created_at: row.get(8)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(commands)
    }

    pub fn get_command(&self, id: &str) -> anyhow::Result<Option<Command>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, server_id, label, command, confirm, timeout_sec, sort_order, pinned, created_at FROM commands WHERE id=?1"
        )?;
        let cmd = stmt.query_row(params![id], |row| {
            Ok(Command {
                id: row.get(0)?,
                server_id: row.get(1)?,
                label: row.get(2)?,
                command: row.get(3)?,
                confirm: row.get(4)?,
                timeout_sec: row.get(5)?,
                sort_order: row.get(6)?,
                pinned: row.get(7)?,
                created_at: row.get(8)?,
            })
        }).optional()?;
        Ok(cmd)
    }

    pub fn create_command(&self, cmd: &NewCommand) -> anyhow::Result<String> {
        let conn = self.conn.lock().unwrap();
        let id = uuid::Uuid::new_v4().to_string();
        conn.execute(
            "INSERT INTO commands (id, server_id, label, command, confirm, timeout_sec, sort_order, pinned) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![id, cmd.server_id, cmd.label, cmd.command, cmd.confirm, cmd.timeout_sec, cmd.sort_order, cmd.pinned],
        )?;
        Ok(id)
    }

    pub fn update_command(&self, id: &str, cmd: &NewCommand) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE commands SET label=?2, command=?3, confirm=?4, timeout_sec=?5, sort_order=?6, pinned=?7 WHERE id=?1",
            params![id, cmd.label, cmd.command, cmd.confirm, cmd.timeout_sec, cmd.sort_order, cmd.pinned],
        )?;
        Ok(())
    }

    pub fn delete_command(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM commands WHERE id = ?1", params![id])?;
        Ok(())
    }

    // --- Suites ---

    pub fn list_suites(&self, server_id: &str) -> anyhow::Result<Vec<Suite>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, server_id, label, created_at FROM suites WHERE server_id=?1 ORDER BY label"
        )?;
        let suites = stmt.query_map(params![server_id], |row| {
            Ok(Suite {
                id: row.get(0)?,
                server_id: row.get(1)?,
                label: row.get(2)?,
                created_at: row.get(3)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(suites)
    }

    pub fn create_suite(&self, suite: &NewSuite) -> anyhow::Result<String> {
        let conn = self.conn.lock().unwrap();
        let id = uuid::Uuid::new_v4().to_string();
        conn.execute(
            "INSERT INTO suites (id, server_id, label) VALUES (?1, ?2, ?3)",
            params![id, suite.server_id, suite.label],
        )?;
        Ok(id)
    }

    pub fn delete_suite(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM suites WHERE id = ?1", params![id])?;
        Ok(())
    }

    pub fn list_suite_steps(&self, suite_id: &str) -> anyhow::Result<Vec<SuiteStep>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, suite_id, command_id, step_order, continue_on_fail FROM suite_steps WHERE suite_id=?1 ORDER BY step_order"
        )?;
        let steps = stmt.query_map(params![suite_id], |row| {
            Ok(SuiteStep {
                id: row.get(0)?,
                suite_id: row.get(1)?,
                command_id: row.get(2)?,
                step_order: row.get(3)?,
                continue_on_fail: row.get(4)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(steps)
    }

    // --- SSH Keys ---

    pub fn list_keys(&self) -> anyhow::Result<Vec<SshKeyMeta>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, label, public_key, key_type, created_at FROM ssh_keys ORDER BY label"
        )?;
        let keys = stmt.query_map([], |row| {
            Ok(SshKeyMeta {
                id: row.get(0)?,
                label: row.get(1)?,
                public_key: row.get(2)?,
                key_type: row.get(3)?,
                created_at: row.get(4)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(keys)
    }

    pub fn get_encrypted_key(&self, id: &str) -> anyhow::Result<Option<EncryptedKey>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, encrypted_key, public_key, key_type FROM ssh_keys WHERE id=?1"
        )?;
        let key = stmt.query_row(params![id], |row| {
            Ok(EncryptedKey {
                id: row.get(0)?,
                encrypted_key: row.get(1)?,
                public_key: row.get(2)?,
                key_type: row.get(3)?,
            })
        }).optional()?;
        Ok(key)
    }

    pub fn store_key(&self, id: &str, label: &str, encrypted_key: &[u8], public_key: &str, key_type: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO ssh_keys (id, label, encrypted_key, public_key, key_type) VALUES (?1, ?2, ?3, ?4, ?5)",
            params![id, label, encrypted_key, public_key, key_type],
        )?;
        Ok(())
    }

    pub fn delete_key(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM ssh_keys WHERE id = ?1", params![id])?;
        Ok(())
    }

    // --- Auth Tokens ---

    pub fn store_token(&self, id: &str, label: &str, token_hash: &str, device_type: Option<&str>) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO api_tokens (id, label, token_hash, device_type) VALUES (?1, ?2, ?3, ?4)",
            params![id, label, token_hash, device_type],
        )?;
        Ok(())
    }

    pub fn list_tokens(&self) -> anyhow::Result<Vec<ApiToken>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, label, device_type, last_used, created_at FROM api_tokens ORDER BY created_at DESC"
        )?;
        let tokens = stmt.query_map([], |row| {
            Ok(ApiToken {
                id: row.get(0)?,
                label: row.get(1)?,
                device_type: row.get(2)?,
                last_used: row.get(3)?,
                created_at: row.get(4)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(tokens)
    }

    pub fn get_token_hash(&self, id: &str) -> anyhow::Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        let hash: Option<String> = conn.query_row(
            "SELECT token_hash FROM api_tokens WHERE id=?1", params![id], |r| r.get(0)
        ).optional()?;
        Ok(hash)
    }

    pub fn verify_token_by_hash(&self, token_hash: &str) -> anyhow::Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        // We need to iterate all tokens and verify against argon2
        // This is handled in the auth module instead
        let mut stmt = conn.prepare("SELECT id, token_hash FROM api_tokens")?;
        let tokens: Vec<(String, String)> = stmt.query_map([], |row| {
            Ok((row.get(0)?, row.get(1)?))
        })?.collect::<Result<Vec<_>, _>>()?;
        // Return all for the auth layer to verify
        drop(stmt);
        drop(conn);
        // Actually this should be handled differently
        Ok(None)
    }

    pub fn all_token_hashes(&self) -> anyhow::Result<Vec<(String, String)>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, token_hash FROM api_tokens")?;
        let tokens = stmt.query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(tokens)
    }

    pub fn token_count(&self) -> anyhow::Result<usize> {
        let conn = self.conn.lock().unwrap();
        let count: usize = conn.query_row("SELECT COUNT(*) FROM api_tokens", [], |r| r.get(0))?;
        Ok(count)
    }

    pub fn update_token_last_used(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "UPDATE api_tokens SET last_used=datetime('now') WHERE id=?1", params![id]
        )?;
        Ok(())
    }

    pub fn delete_token(&self, id: &str) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM api_tokens WHERE id = ?1", params![id])?;
        Ok(())
    }

    // --- Exec History ---

    pub fn record_execution(&self, entry: &ExecEntry) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO exec_history (id, server_id, command_id, suite_id, command_text, exit_code, stdout, stderr, duration_ms, device) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![entry.id, entry.server_id, entry.command_id, entry.suite_id, entry.command_text, entry.exit_code, entry.stdout, entry.stderr, entry.duration_ms, entry.device],
        )?;
        Ok(())
    }

    pub fn list_history(&self, limit: u32) -> anyhow::Result<Vec<ExecEntry>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, server_id, command_id, suite_id, command_text, exit_code, stdout, stderr, duration_ms, device, created_at FROM exec_history ORDER BY created_at DESC LIMIT ?1"
        )?;
        let entries = stmt.query_map(params![limit], |row| {
            Ok(ExecEntry {
                id: row.get(0)?,
                server_id: row.get(1)?,
                command_id: row.get(2)?,
                suite_id: row.get(3)?,
                command_text: row.get(4)?,
                exit_code: row.get(5)?,
                stdout: row.get(6)?,
                stderr: row.get(7)?,
                duration_ms: row.get(8)?,
                device: row.get(9)?,
                created_at: row.get(10)?,
            })
        })?.collect::<Result<Vec<_>, _>>()?;
        Ok(entries)
    }

    // --- Master passphrase ---

    pub fn get_master_salt(&self) -> anyhow::Result<Option<Vec<u8>>> {
        let conn = self.conn.lock().unwrap();
        let salt: Option<Vec<u8>> = conn.query_row(
            "SELECT value FROM meta WHERE key='master_salt'", [], |r| r.get(0)
        ).optional()?;
        Ok(salt)
    }

    pub fn get_master_verify(&self) -> anyhow::Result<Option<Vec<u8>>> {
        let conn = self.conn.lock().unwrap();
        let verify: Option<Vec<u8>> = conn.query_row(
            "SELECT value FROM meta WHERE key='master_verify'", [], |r| r.get(0)
        ).optional()?;
        Ok(verify)
    }

    pub fn set_master_credentials(&self, salt: &[u8], verify: &[u8]) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR REPLACE INTO meta (key, value) VALUES ('master_salt', ?1)",
            params![salt],
        )?;
        conn.execute(
            "INSERT OR REPLACE INTO meta (key, value) VALUES ('master_verify', ?1)",
            params![verify],
        )?;
        Ok(())
    }
}

// Use rusqlite's optional extension
trait OptionalExt<T> {
    fn optional(self) -> rusqlite::Result<Option<T>>;
}

impl<T> OptionalExt<T> for rusqlite::Result<T> {
    fn optional(self) -> rusqlite::Result<Option<T>> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}

const MIGRATIONS: &str = r#"
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value BLOB
);

CREATE TABLE IF NOT EXISTS servers (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    host        TEXT NOT NULL,
    port        INTEGER NOT NULL DEFAULT 22,
    user        TEXT NOT NULL,
    key_id      TEXT,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    status      TEXT DEFAULT 'unknown',
    latency_ms  INTEGER,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS ssh_keys (
    id              TEXT PRIMARY KEY,
    label           TEXT NOT NULL,
    encrypted_key   BLOB NOT NULL,
    public_key      TEXT NOT NULL,
    key_type        TEXT NOT NULL DEFAULT 'ed25519',
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS commands (
    id          TEXT PRIMARY KEY,
    server_id   TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    command     TEXT NOT NULL,
    confirm     BOOLEAN NOT NULL DEFAULT 1,
    timeout_sec INTEGER NOT NULL DEFAULT 30,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    pinned      BOOLEAN NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS suites (
    id          TEXT PRIMARY KEY,
    server_id   TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS suite_steps (
    id               TEXT PRIMARY KEY,
    suite_id         TEXT NOT NULL REFERENCES suites(id) ON DELETE CASCADE,
    command_id       TEXT NOT NULL REFERENCES commands(id),
    step_order       INTEGER NOT NULL,
    continue_on_fail BOOLEAN NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS api_tokens (
    id          TEXT PRIMARY KEY,
    label       TEXT NOT NULL,
    token_hash  TEXT NOT NULL,
    device_type TEXT,
    last_used   TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS totp_secrets (
    id          TEXT PRIMARY KEY,
    secret      BLOB NOT NULL,
    enabled     BOOLEAN NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS exec_history (
    id           TEXT PRIMARY KEY,
    server_id    TEXT NOT NULL,
    command_id   TEXT,
    suite_id     TEXT,
    command_text TEXT,
    exit_code    INTEGER,
    stdout       TEXT,
    stderr       TEXT,
    duration_ms  INTEGER,
    device       TEXT,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS apns_devices (
    id           TEXT PRIMARY KEY,
    device_token TEXT NOT NULL,
    device_type  TEXT NOT NULL,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS server_alert_prefs (
    server_id   TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    device_id   TEXT NOT NULL REFERENCES apns_devices(id) ON DELETE CASCADE,
    enabled     BOOLEAN NOT NULL DEFAULT 1,
    PRIMARY KEY (server_id, device_id)
);
"#;
