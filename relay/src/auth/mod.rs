mod middleware;

pub use middleware::auth_middleware;

use aes_gcm::{Aes256Gcm, KeyInit, Nonce};
use aes_gcm::aead::Aead;
use argon2::{Argon2, PasswordHasher, PasswordVerifier, password_hash::SaltString};
use rand::rngs::OsRng;
use std::io::{self, Write, BufRead};

use crate::config::RelayConfig;
use crate::db::Database;

/// Derive a 32-byte encryption key from a passphrase + salt using Argon2id
pub fn derive_key(passphrase: &str, salt: &[u8]) -> [u8; 32] {
    use argon2::{Algorithm, Version, Params};
    let params = Params::new(65536, 3, 1, Some(32)).unwrap();
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut key = [0u8; 32];
    argon2.hash_password_into(passphrase.as_bytes(), salt, &mut key).unwrap();
    key
}

/// Encrypt data with AES-256-GCM
pub fn encrypt(key: &[u8; 32], plaintext: &[u8]) -> anyhow::Result<Vec<u8>> {
    let cipher = Aes256Gcm::new_from_slice(key)?;
    let nonce_bytes: [u8; 12] = rand::random();
    let nonce = Nonce::from_slice(&nonce_bytes);
    let ciphertext = cipher.encrypt(nonce, plaintext)
        .map_err(|e| anyhow::anyhow!("Encryption failed: {}", e))?;
    // Prepend nonce to ciphertext
    let mut result = nonce_bytes.to_vec();
    result.extend_from_slice(&ciphertext);
    Ok(result)
}

/// Decrypt data with AES-256-GCM (expects nonce prepended)
pub fn decrypt(key: &[u8; 32], data: &[u8]) -> anyhow::Result<Vec<u8>> {
    if data.len() < 12 {
        anyhow::bail!("Data too short to contain nonce");
    }
    let (nonce_bytes, ciphertext) = data.split_at(12);
    let cipher = Aes256Gcm::new_from_slice(key)?;
    let nonce = Nonce::from_slice(nonce_bytes);
    let plaintext = cipher.decrypt(nonce, ciphertext)
        .map_err(|e| anyhow::anyhow!("Decryption failed: {}", e))?;
    Ok(plaintext)
}

/// Hash a token for storage using Argon2
pub fn hash_token(token: &str) -> anyhow::Result<String> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let hash = argon2.hash_password(token.as_bytes(), &salt)
        .map_err(|e| anyhow::anyhow!("Hash failed: {}", e))?;
    Ok(hash.to_string())
}

/// Verify a token against an Argon2 hash
pub fn verify_token(token: &str, hash: &str) -> bool {
    let parsed = match argon2::PasswordHash::new(hash) {
        Ok(h) => h,
        Err(_) => return false,
    };
    Argon2::default().verify_password(token.as_bytes(), &parsed).is_ok()
}

/// Generate a random API token
pub fn generate_token() -> String {
    use base64::Engine;
    let bytes: [u8; 32] = rand::random();
    format!("tap_{}", base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(bytes))
}

/// First-time setup or unlock existing master passphrase
pub async fn setup_or_unlock(db: &Database, _config: &RelayConfig) -> anyhow::Result<[u8; 32]> {
    let existing_salt = db.get_master_salt()?;

    if let Some(salt) = existing_salt {
        // Existing setup — prompt for passphrase
        let verify_data = db.get_master_verify()?
            .ok_or_else(|| anyhow::anyhow!("Corrupted DB: salt exists but no verify token"))?;

        loop {
            let passphrase = prompt_passphrase("Enter master passphrase: ")?;
            let key = derive_key(&passphrase, &salt);

            // Try to decrypt the verify token
            if decrypt(&key, &verify_data).is_ok() {
                tracing::info!("Master passphrase accepted");
                return Ok(key);
            }
            eprintln!("Incorrect passphrase. Try again.");
        }
    } else {
        // First-time setup
        println!("\n  Welcome to Tap Relay!\n");
        println!("  Set a master passphrase to encrypt your SSH keys at rest.");
        println!("  You'll need this passphrase every time the relay starts.\n");

        let passphrase = loop {
            let p1 = prompt_passphrase("  New master passphrase: ")?;
            if p1.len() < 8 {
                eprintln!("  Passphrase must be at least 8 characters.");
                continue;
            }
            let p2 = prompt_passphrase("  Confirm passphrase: ")?;
            if p1 != p2 {
                eprintln!("  Passphrases don't match. Try again.");
                continue;
            }
            break p1;
        };

        // Generate salt and derive key
        let salt: [u8; 16] = rand::random();
        let key = derive_key(&passphrase, &salt);

        // Create a verify token (encrypt a known value)
        let verify_plaintext = b"tap-relay-verify";
        let verify_encrypted = encrypt(&key, verify_plaintext)?;

        db.set_master_credentials(&salt, &verify_encrypted)?;

        // Generate first API token
        let token = generate_token();
        let token_hash = hash_token(&token)?;
        let token_id = uuid::Uuid::new_v4().to_string();
        db.store_token(&token_id, "Initial setup token", &token_hash, Some("cli"))?;

        println!("\n  Setup complete!\n");
        println!("  Your first API token (save this — it won't be shown again):\n");
        println!("    {}\n", token);
        println!("  Use this token in your watch/companion app to connect.\n");

        Ok(key)
    }
}

fn prompt_passphrase(prompt: &str) -> io::Result<String> {
    eprint!("{}", prompt);
    io::stderr().flush()?;
    let mut line = String::new();
    io::stdin().lock().read_line(&mut line)?;
    Ok(line.trim().to_string())
}
