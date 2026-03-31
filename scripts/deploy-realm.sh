#!/usr/bin/env bash
#
# Deploy/manage the Macula Realm production platform.
#
# Usage:
#   ./scripts/deploy-realm.sh <command> [--sshpass <file>]
#
# Commands:
#   init      First-time setup (build Caddy, pull images, start)
#   up        Start all services
#   down      Stop all services
#   update    Pull new images and restart
#   migrate   Run database migrations
#   deploy    Full deploy: pull, migrate, restart
#   logs      Show logs (optionally: logs <service>)
#   status    Show service status
#   backup    Backup database
#
# Remote usage (deploy to a server):
#   ./scripts/deploy-realm.sh init --host root@macula.io [--sshpass <file>]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REALM_DIR="${REPO_DIR}/realm"

# ── Parse args ─────────────────────────────────────────────────────
COMMAND=""
SSH_HOST=""
SSHPASS_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            SSH_HOST="$2"
            shift 2
            ;;
        --sshpass)
            SSHPASS_FILE="$2"
            shift 2
            ;;
        -*)
            EXTRA_ARGS+=("$1")
            shift
            ;;
        *)
            if [[ -z "$COMMAND" ]]; then
                COMMAND="$1"
            else
                EXTRA_ARGS+=("$1")
            fi
            shift
            ;;
    esac
done

if [[ -z "$COMMAND" ]]; then
    echo "Usage: $0 <command> [--host <ssh-host>] [--sshpass <file>]"
    echo ""
    echo "Commands: init, up, down, update, migrate, deploy, logs, status, backup"
    exit 1
fi

# ── Remote mode ───────────────────────────────────────────────────
if [[ -n "$SSH_HOST" ]]; then
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

    echo "=== Remote deploy to ${SSH_HOST} ==="

    # Sync realm/ directory (preserve .env and docker-config.json)
    ssh_cmd 'mkdir -p /root/macula-demo'
    ssh_cmd 'cp /root/macula-demo/realm/.env /tmp/realm-env-backup 2>/dev/null || true; cp /root/macula-demo/realm/docker-config.json /tmp/realm-docker-config-backup 2>/dev/null || true'
    scp_cmd "${REALM_DIR}" "/root/macula-demo/"
    ssh_cmd 'cp /tmp/realm-env-backup /root/macula-demo/realm/.env 2>/dev/null || true; cp /tmp/realm-docker-config-backup /root/macula-demo/realm/docker-config.json 2>/dev/null || true'

    # Run command remotely
    ssh_cmd "cd /root/macula-demo && ./scripts/deploy-realm.sh ${COMMAND} ${EXTRA_ARGS[*]:-}"
    exit $?
fi

# ── Local mode (running on the target host) ───────────────────────
COMPOSE="docker compose -f ${REALM_DIR}/docker-compose.yml"

check_env() {
    if [[ ! -f "${REALM_DIR}/.env" ]]; then
        echo "ERROR: ${REALM_DIR}/.env not found"
        echo "  cp ${REALM_DIR}/.env.example ${REALM_DIR}/.env"
        exit 1
    fi
}

case "$COMMAND" in
    init)
        check_env
        echo "--- Building Caddy image ---"
        $COMPOSE build caddy
        echo "--- Pulling images ---"
        $COMPOSE pull
        echo "--- Starting services ---"
        $COMPOSE up -d
        echo "Initialization complete. Caddy will provision TLS certs automatically."
        ;;
    up)
        check_env
        $COMPOSE up -d
        echo "Services started."
        ;;
    down)
        $COMPOSE down
        ;;
    update)
        check_env
        $COMPOSE pull
        $COMPOSE up -d --force-recreate
        echo "Update complete."
        ;;
    migrate)
        check_env
        $COMPOSE exec realm /app/bin/migrate
        echo "Migrations complete."
        ;;
    deploy)
        check_env
        echo "--- Pulling images ---"
        $COMPOSE pull
        echo "--- Restarting services ---"
        $COMPOSE up -d --force-recreate
        echo "--- Running migrations ---"
        sleep 5
        $COMPOSE exec realm /app/bin/migrate
        echo "Deployment complete."
        $COMPOSE ps
        ;;
    logs)
        $COMPOSE logs -f "${EXTRA_ARGS[@]:-}"
        ;;
    status)
        $COMPOSE ps
        ;;
    backup)
        "${REALM_DIR}/scripts/backup-db.sh"
        ;;
    *)
        echo "Unknown command: $COMMAND"
        echo "Commands: init, up, down, update, migrate, deploy, logs, status, backup"
        exit 1
        ;;
esac
