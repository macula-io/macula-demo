#!/bin/bash
# Deploy co-located relays on relay00 Hetzner box (91.98.238.177)
#
# Replaces the single-relay compose with multi-relay compose.
# relay00 keeps port 4433, new relays get 4434, 4435.
#
# Usage: ./scripts/deploy-colocated-relay00.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOST="root@relay00.macula.io"
REMOTE_DIR="/root/macula-realm-compose"
LOCAL_DIR="${SCRIPT_DIR}/relay/colocated-hetzner"

echo "=== Deploying co-located relays to relay00.macula.io ==="

# Copy new compose + Caddyfile
echo "[1/4] Uploading compose files..."
scp "${LOCAL_DIR}/docker-compose.yml" "${HOST}:${REMOTE_DIR}/docker-compose-colocated.yml"
scp "${LOCAL_DIR}/Caddyfile" "${HOST}:${REMOTE_DIR}/caddy/Caddyfile.relay"

# Read existing LINODE_DNS_API_TOKEN from .env
echo "[2/4] Stopping old compose..."
ssh "${HOST}" "cd ${REMOTE_DIR} && docker compose -f docker-compose-relay.yml down"

echo "[3/4] Starting co-located compose..."
ssh "${HOST}" "cd ${REMOTE_DIR} && docker compose -f docker-compose-colocated.yml up -d --build"

echo "[4/4] Waiting for certs and health..."
sleep 10
for fqdn in relay00.macula.io relay-nl-amsterdam.macula.io relay-pl-lodz.macula.io; do
    result=$(curl -sf "https://${fqdn}/status" --max-time 5 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "not ready")
    echo "  ${fqdn}: ${result}"
done

echo ""
echo "Done. New relays need ~30s for cert issuance on first boot."
echo "Check: curl https://relay-nl-amsterdam.macula.io/status"
