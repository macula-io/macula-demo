# CLAUDE.md - Macula Demo

## Overview

Deployment and demo toolkit for the Macula platform. This is NOT a code repo — it contains compose files, config templates, and scripts to deploy and demonstrate Macula infrastructure.

## Four Deployment Scenarios

### 1. Relay (`relay/`)
Deploys `macula-relay` (QUIC message router) to VPS machines.
- Caddy handles TLS certs via Linode DNS-01
- Watchtower auto-pulls from ghcr.io
- Image built by CI in `macula-io/macula-relay`

### 2. Daemon (`daemon/`)
Deploys `hecate-daemon` (headless node) to beam cluster or nanodes.
- host networking, connects to relay mesh
- BEAM clustering via Erlang distribution
- Image built by CI in `hecate-social/hecate-daemon`

### 3. Realm (`realm/`)
Deploys the macula.io production platform (realm + central + auctions + postgres + caddy).
- Wildcard TLS for *.macula.io via Linode DNS-01
- TimescaleDB for persistence
- Erlang clustering between central and auctions
- Relay is NOT included — deployed separately via `relay/`
- Image built by CI in `macula-io/macula-realm`, `macula-io/macula-central`, `macula-io/macula-auctions`

### 4. Local (`local/`)
Runs an attended Hecate node on a developer machine.
- hecate-daemon in container (Docker/Podman)
- hecate-web as native Tauri binary
- Connected to relay mesh

## Scripts

| Script | Purpose |
|--------|---------|
| `provision-relay.sh` | First-time VPS setup (Docker, firewall, copy config) |
| `deploy-relay.sh` | Deploy/redeploy relay compose stack |
| `deploy-daemon.sh` | Deploy/redeploy daemon to headless node |
| `start-local.sh` | Start local daemon + web |
| `stop-local.sh` | Stop local daemon + web |
| `deploy-realm.sh` | Deploy/manage realm platform |
| `demo.sh` | Interactive mesh demo (topology, chaos mode) |

## Secrets

`.env`, `docker-config.json`, `hecate-daemon.env`, `llm-providers.env` are gitignored. Only `.example` templates are committed.

## Current Relay Fleet

| Relay | Host | Location |
|-------|------|----------|
| relay00 | Hetzner | Nuremberg, DE |
| relay01 | Hetzner | Helsinki, FI |
| relay02 | Linode | US (runs full realm compose) |
| relay03 | Hetzner | DE |

## Current Beam Cluster

| Node | IP | RAM |
|------|-----|-----|
| beam00.lab | 192.168.1.10 | 16GB |
| beam01.lab | 192.168.1.11 | 32GB |
| beam02.lab | 192.168.1.12 | 32GB |
| beam03.lab | 192.168.1.13 | 32GB |
