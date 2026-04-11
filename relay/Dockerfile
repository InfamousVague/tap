FROM rust:1.77-slim as builder

RUN apt-get update && apt-get install -y pkg-config libssl-dev cmake && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
COPY src ./src

RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/tap-relay /usr/local/bin/tap-relay

RUN mkdir -p /var/lib/tap /etc/tap

EXPOSE 8443

ENTRYPOINT ["tap-relay"]
