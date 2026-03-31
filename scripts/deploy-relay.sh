#!/usr/bin/env bash
#
# Deploy (or redeploy) a Macula relay on a provisioned host.
#
# Usage:
#   ./scripts/deploy-relay.sh <ssh-host> [--sshpass <file>] [--sync]
#
# Options:
#   --sshpass <file>  Use sshpass for password-based SSH
#   --sync            Re-copy relay/ directory before deploying (updates config)
#
# Example:
#   ./scripts/deploy-relay.sh root@relay03.macula.io --sshpass ~/.config/macula/sshpass.txt
#   ./scripts/deploy-relay.sh root@relay00.macula.io --sync
#
# Prerequisites:
#   - Host provisioned with provision-relay.sh
#   - .env and docker-config.json configured on the host
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ── Parse args ─────────────────────────────────────────────────────
SSH_HOST=""
SSHPASS_FILE=""
SYNC=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sshpass)
            SSHPASS_FILE="$2"
            shift 2
            ;;
        --sync)
            SYNC=true
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            SSH_HOST="$1"
            shift
            ;;
    esac
done

if [[ -z "$SSH_HOST" ]]; then
    echo "Usage: $0 <ssh-host> [--sshpass <file>] [--sync]" >&2
    exit 1
fi

# ── SSH/SCP helpers ────────────────────────────────────────────────
ssh_cmd() {
    if [[ -n "$SSHPASS_FILE" ]]; then
        sshpass -f "$SSHPASS_FILE" ssh -o StrictHostKeyChecking=no "$SSH_HOST" "$1"
    else
        ssh -o StrictHostKeyChecking=no "$SSH_HOST" "$1"
    fi
}

scp_cmd() {
    if [[ -n "$SSHPASS_FILE" ]]; then
        sshpass -f "$SSHPASS_FILE" scp -o StrictHostKeyChecking=no -r "$1" "$SSH_HOST:$2"
    else
        scp -o StrictHostKeyChecking=no -r "$1" "$SSH_HOST:$2"
    fi
}

echo "=== Deploying relay to ${SSH_HOST} ==="

# ── Sync config if requested ──────────────────────────────────────
if [[ "$SYNC" == true ]]; then
    echo "--- Syncing relay config ---"
    # Preserve .env and docker-config.json on remote
    ssh_cmd 'cp /root/macula-demo/relay/.env /tmp/relay-env-backup 2>/dev/null || true; cp /root/macula-demo/relay/docker-config.json /tmp/relay-docker-config-backup 2>/dev/null || true'
    scp_cmd "${REPO_DIR}/relay" "/root/macula-demo/"
    ssh_cmd 'cp /tmp/relay-env-backup /root/macula-demo/relay/.env 2>/dev/null || true; cp /tmp/relay-docker-config-backup /root/macula-demo/relay/docker-config.json 2>/dev/null || true'
    echo "Config synced (preserved .env and docker-config.json)"
fi

# ── Verify config exists ──────────────────────────────────────────
echo "--- Checking config ---"
ssh_cmd '
    cd /root/macula-demo/relay
    if [[ ! -f .env ]]; then
        echo "ERROR: /root/macula-demo/relay/.env not found" >&2
        echo "  Run: cp .env.example .env  and edit it" >&2
        exit 1
    fi
    if [[ ! -f docker-config.json ]]; then
        echo "ERROR: /root/macula-demo/relay/docker-config.json not found" >&2
        echo "  Run: cp docker-config.json.example docker-config.json  and edit it" >&2
        exit 1
    fi
    source .env
    echo "  RELAY_HOSTNAME=${RELAY_HOSTNAME}"
    echo "  MACULA_RELAYS=${MACULA_RELAYS:-<not set>}"
'

# ── Deploy ────────────────────────────────────────────────────────
echo "--- Deploying ---"
ssh_cmd 'cd /root/macula-demo/relay && docker compose down --remove-orphans 2>/dev/null; docker compose up -d --build'

echo ""
echo "--- Waiting 30s for Caddy to obtain TLS cert... ---"
sleep 30

# ── Verify ────────────────────────────────────────────────────────
echo "--- Verifying ---"
ssh_cmd '
    echo "Containers:"
    docker ps --format "  {{.Names}}: {{.Status}}"
    echo ""
    echo "Relay health:"
    curl -sf http://localhost:8080/health 2>/dev/null && echo " OK" || echo " FAIL (may need more time for TLS)"
'

echo ""
echo "=== Deployment complete ==="
