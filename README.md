# Tap

> The command remote for your infrastructure.

Run pre-configured SSH commands on remote servers from your Apple Watch. Tap, confirm, done.

## Architecture

```
Watch ←── HTTPS/TLS 1.3 ──► Relay ←── SSH ──► Your Servers
                                │
Companion ←── HTTPS/TLS 1.3 ───┘
```

## Monorepo Structure

| Directory | Description |
|-----------|-------------|
| `relay/` | Rust backend (axum + russh + SQLite) |
| `watch/` | watchOS app (Swift + SwiftUI) |
| `companion/` | iOS/iPad/Mac app (React Native + Expo) |
| `base-rn/` | React Native UI kit |

## Quick Start

### Relay

```bash
cd relay
cargo run
# First run: sets master passphrase, generates API token
```

## License

MIT
