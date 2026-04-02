#!/usr/bin/env bash
#
# Set MACULA_ADMIN_TOKEN on all relay boxes and beam nodes.
#
# Usage: ./scripts/set-admin-token.sh <token>
#
# This adds the token to the relevant .env or compose env files
# and restarts containers to pick up the new value.

set -euo pipefail

TOKEN="${1:?Usage: $0 <token>}"

RELAY_HOSTS=(relay00.macula.io relay01.macula.io macula.io)
RELAY_SSH_USER=root
# Paths where relay compose .env or env files live
RELAY_ENV_PATHS=(
    "/root/macula-relay/.env"
    "/root/macula-relay/.env"
    "/root/macula-demo/relay/.env"
)

BEAM_NODES=(beam00 beam01 beam02 beam03)
BEAM_SSH_USER=rl
# Stub compose env path on beam nodes
STUB_ENV_PATH="$HOME/.hecate/compose/stub.env"

echo "Setting MACULA_ADMIN_TOKEN on all hosts..."
echo ""

# ── Relay boxes ────────────────────────────────────────────────────
for i in "${!RELAY_HOSTS[@]}"; do
    host="${RELAY_HOSTS[$i]}"
    env_path="${RELAY_ENV_PATHS[$i]}"
    echo -n "  relay: ${host} ... "
    ssh -o ConnectTimeout=5 "${RELAY_SSH_USER}@${host}" bash -s <<REMOTE
        # Remove old token line if present, add new one
        touch "${env_path}"
        grep -v '^MACULA_ADMIN_TOKEN=' "${env_path}" > "${env_path}.tmp" || true
        echo "MACULA_ADMIN_TOKEN=${TOKEN}" >> "${env_path}.tmp"
        mv "${env_path}.tmp" "${env_path}"
        # Also set in running containers directly (takes effect on restart)
        docker exec macula-relay sh -c "export MACULA_ADMIN_TOKEN=${TOKEN}" 2>/dev/null || true
REMOTE
    echo "done"
done

echo ""

# ── Beam nodes (stub containers) ──────────────────────────────────
for node in "${BEAM_NODES[@]}"; do
    echo -n "  beam:  ${node}.lab ... "
    ssh -o ConnectTimeout=5 "${BEAM_SSH_USER}@${node}.lab" bash -s <<REMOTE
        # Create stub env file if missing
        mkdir -p "\$(dirname ${STUB_ENV_PATH})"
        touch "${STUB_ENV_PATH}"
        grep -v '^MACULA_ADMIN_TOKEN=' "${STUB_ENV_PATH}" > "${STUB_ENV_PATH}.tmp" || true
        echo "MACULA_ADMIN_TOKEN=${TOKEN}" >> "${STUB_ENV_PATH}.tmp"
        mv "${STUB_ENV_PATH}.tmp" "${STUB_ENV_PATH}"
REMOTE
    echo "done"
done

echo ""
echo "Token set on all hosts."
echo "Containers will pick up the token after restart (Watchtower or manual)."
echo ""
echo "To force immediate restart:"
echo "  Relays:  ssh root@relay0X.macula.io 'docker restart macula-relay'"
echo "  Stubs:   ssh rl@beam0X.lab 'docker restart hecate-stubs'"
