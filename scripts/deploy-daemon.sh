#!/usr/bin/env bash
#
# Deploy (or redeploy) hecate-daemon to a headless node (beam cluster / nanode).
#
# Usage:
#   ./scripts/deploy-daemon.sh <ssh-host> [--sshpass <file>] [--sync]
#
# Example:
#   ./scripts/deploy-daemon.sh rl@beam00.lab --sshpass ~/.config/macula/sshpass.txt
#   ./scripts/deploy-daemon.sh rl@nanode01.lab
#
# The script:
#   1. Copies daemon/ compose + env templates to the target
#   2. Creates hecate-daemon.env from node-specific config
#   3. Starts the daemon + watchtower via Docker Compose
#
# Prerequisites:
#   - SSH access to the target node
#   - Docker installed on the target
#   - ghcr.io auth configured (docker-config.json)
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

DEPLOY_DIR="\$HOME/.hecate/compose"

echo "=== Deploying hecate-daemon to ${SSH_HOST} ==="

# ── Ensure target directory ───────────────────────────────────────
ssh_cmd "mkdir -p ${DEPLOY_DIR}"

# ── Copy compose file ─────────────────────────────────────────────
if [[ "$SYNC" == true ]] || ! ssh_cmd "test -f ${DEPLOY_DIR}/docker-compose.yml" 2>/dev/null; then
    echo "--- Copying compose config ---"
    scp_cmd "${REPO_DIR}/daemon/docker-compose.yml" "${DEPLOY_DIR}/docker-compose.yml"
fi

# ── Copy example files if env files don't exist ──────────────────
ssh_cmd "
    cd ${DEPLOY_DIR}
    if [[ ! -f .env ]]; then
        echo 'WARNING: No .env found — creating from example'
        cat > .env << 'ENVEOF'
HECATE_HOSTNAME=\$(hostname)
HECATE_USER=\$(whoami)
HOST_HOME=\${HOME}
HECATE_VERSION=main
HECATE_HOME=/fast/.hecate
ENVEOF
        echo '  Edit ${DEPLOY_DIR}/.env with node-specific values'
    fi

    if [[ ! -f hecate-daemon.env ]]; then
        echo 'WARNING: No hecate-daemon.env found — you must create one'
        echo '  See: daemon/hecate-daemon.env.example in macula-demo repo'
    fi

    if [[ ! -f llm-providers.env ]]; then
        touch llm-providers.env
    fi

    if [[ ! -f docker-config.json ]]; then
        echo 'WARNING: No docker-config.json found — watchtower needs it for ghcr.io pulls'
    fi
"

# ── Verify required files ─────────────────────────────────────────
echo "--- Checking config ---"
HAS_CONFIG=$(ssh_cmd "
    cd ${DEPLOY_DIR}
    ok=true
    [[ ! -f .env ]] && echo 'MISSING: .env' && ok=false
    [[ ! -f hecate-daemon.env ]] && echo 'MISSING: hecate-daemon.env' && ok=false
    [[ ! -f docker-config.json ]] && echo 'MISSING: docker-config.json' && ok=false
    \$ok && echo 'OK'
")

if [[ "$HAS_CONFIG" != "OK" ]]; then
    echo "$HAS_CONFIG"
    echo ""
    echo "Fix the missing files, then re-run this script."
    exit 1
fi

ssh_cmd "cd ${DEPLOY_DIR} && source .env && echo '  HECATE_HOSTNAME=\${HECATE_HOSTNAME}' && echo '  HECATE_HOME=\${HECATE_HOME}'"

# ── Deploy ────────────────────────────────────────────────────────
echo "--- Deploying ---"
ssh_cmd "cd ${DEPLOY_DIR} && docker compose down 2>/dev/null; docker compose up -d"

echo ""
echo "--- Verifying ---"
ssh_cmd '
    echo "Containers:"
    docker ps --format "  {{.Names}}: {{.Status}}"
'

echo ""
echo "=== Deployment complete ==="
