# Macula Demo

Deployment toolkit for the Macula platform: relay mesh, realm platform, daemon nodes, and local development.

## Quick Start

### Deploy a relay

```bash
# Provision a fresh VPS
./scripts/provision-relay.sh root@relay03.macula.io --sshpass ~/.config/macula/sshpass.txt

# Configure (on the remote host)
cd /root/macula-demo/relay
cp .env.example .env
cp docker-config.json.example docker-config.json

# Deploy
./scripts/deploy-relay.sh root@relay03.macula.io --sshpass ~/.config/macula/sshpass.txt
```

### Deploy the realm platform

```bash
# Remote deploy to macula.io
./scripts/deploy-realm.sh init --host root@macula.io

# Or locally on the server
cd realm && cp .env.example .env && ./scripts/setup-ghcr-auth.sh
./scripts/deploy-realm.sh init
```

### Deploy a daemon node

```bash
./scripts/deploy-daemon.sh rl@beam00.lab
```

### Run a local attended node

```bash
./scripts/start-local.sh         # daemon + web
./scripts/start-local.sh --daemon-only
./scripts/stop-local.sh
```

### Interactive demo

```bash
./scripts/demo.sh
```

## Structure

```
relay/              Standalone relay deployment (VPS machines)
  docker-compose.yml
  caddy/            Caddy with Linode DNS plugin (TLS via DNS-01)

realm/              Macula.io production platform
  docker-compose.yml
  caddy/            Caddy with wildcard TLS for *.macula.io
  scripts/          DB init, backup, ghcr auth

daemon/             Headless daemon deployment (beam cluster / nanodes)
  docker-compose.yml

local/              Local attended node (developer machine)
  docker-compose.yml

scripts/            Deployment and demo scripts
  provision-relay.sh
  deploy-relay.sh
  deploy-realm.sh
  deploy-daemon.sh
  start-local.sh / stop-local.sh
  demo.sh
```

## Architecture

```
                         Internet
                            |
               ┌────────────┼────────────┐
               |            |            |
          relay00       relay01       relay03        relay02
         (Nuremberg)   (Helsinki)    (Hetzner)      (Linode)
               |            |            |              |
               └────────────┼────────────┘              |
                            |                           |
           ┌────────────────┼──────────────┐            |
           |                |              |            |
       beam00-03       nanode(s)      local dev    macula.io
       (headless)      (headless)    (attended)    (realm platform)
```

Relays form a full-mesh peering network over QUIC. Nodes connect to one relay and failover to another on disconnect. The realm platform (macula.io) runs independently on its own Linode box alongside relay02.

## Repos that produce the images

| Image | Source Repo | Registry |
|-------|-------------|----------|
| macula-relay | macula-io/macula-relay | ghcr.io |
| hecate-daemon | hecate-social/hecate-daemon | ghcr.io |
| hecate-web | hecate-social/hecate-web | GitHub Releases |
| macula-realm | macula-io/macula-realm | Docker Hub |
| macula-central | macula-io/macula-central | Docker Hub |
| macula-auctions | macula-io/macula-auctions | Docker Hub |

## Supersedes

This repo consolidates and replaces:
- `macula-io/macula-realm-compose` (archived)
- `macula-io/macula-relay/deploy/` (removed)
- `macula-io/macula-relay/scripts/demo.sh` (removed)
