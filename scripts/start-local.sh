#!/usr/bin/env bash
#
# Start a local attended Hecate node (daemon + web).
#
# Usage:
#   ./scripts/start-local.sh [--daemon-only]
#
# What this does:
#   1. Starts hecate-daemon in a container (Docker or Podman)
#   2. Waits for the daemon to be healthy
#   3. Launches hecate-web (pre-built Tauri binary)
#
# Prerequisites:
#   - Docker or Podman installed
#   - local/.env and local/hecate-daemon.env configured
#   - hecate-web binary installed (via hecate-install or manual download)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCAL_DIR="${REPO_DIR}/local"

DAEMON_ONLY=false
[[ "${1:-}" == "--daemon-only" ]] && DAEMON_ONLY=true

# ── Detect container runtime ──────────────────────────────────────
if command -v podman &>/dev/null; then
    COMPOSE="podman compose"
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    COMPOSE="docker compose"
    RUNTIME="docker"
else
    echo "ERROR: Neither docker nor podman found" >&2
    exit 1
fi

echo "=== Starting local Hecate node (${RUNTIME}) ==="

# ── Verify config ─────────────────────────────────────────────────
cd "$LOCAL_DIR"

if [[ ! -f .env ]]; then
    echo "No .env found — creating from example..."
    cp .env.example .env
    echo "  Edit local/.env if needed"
fi

if [[ ! -f hecate-daemon.env ]]; then
    echo "No hecate-daemon.env found — creating from example..."
    cp hecate-daemon.env.example hecate-daemon.env
    echo "  Edit local/hecate-daemon.env with your config"
fi

if [[ ! -f llm-providers.env ]]; then
    touch llm-providers.env
fi

# ── Ensure data directory exists ──────────────────────────────────
source .env 2>/dev/null || true
HECATE_HOME="${HECATE_HOME:-$HOME/.hecate}"
mkdir -p "${HECATE_HOME}/hecate-daemon/sockets"
mkdir -p "${HECATE_HOME}/hecate-daemon/sqlite"
mkdir -p "${HECATE_HOME}/hecate-daemon/reckon-db"

# ── Start daemon ──────────────────────────────────────────────────
echo "--- Starting hecate-daemon ---"
$COMPOSE up -d

echo "--- Waiting for daemon to be healthy..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:4444/health &>/dev/null; then
        echo "  Daemon is healthy"
        break
    fi
    if [[ "$i" -eq 30 ]]; then
        echo "  WARNING: Daemon not healthy after 30s — check logs: $RUNTIME logs hecate-daemon"
    fi
    sleep 1
done

# ── Launch hecate-web ─────────────────────────────────────────────
if [[ "$DAEMON_ONLY" == true ]]; then
    echo ""
    echo "=== Daemon running (--daemon-only mode) ==="
    echo "  Health: curl http://localhost:4444/health"
    echo "  Logs:   $RUNTIME logs -f hecate-daemon"
    echo "  Stop:   ./scripts/stop-local.sh"
    exit 0
fi

HECATE_WEB=""
for candidate in \
    "/usr/bin/hecate-web" \
    "/usr/local/bin/hecate-web" \
    "$HOME/.local/bin/hecate-web" \
    "$HOME/.hecate/bin/hecate-web"; do
    if [[ -x "$candidate" ]]; then
        HECATE_WEB="$candidate"
        break
    fi
done

if [[ -z "$HECATE_WEB" ]]; then
    echo ""
    echo "WARNING: hecate-web binary not found"
    echo "  Install it from: https://github.com/hecate-social/hecate-web/releases"
    echo "  Or run:  curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh | bash"
    echo ""
    echo "  Daemon is running — you can use the API at http://localhost:4444"
    exit 0
fi

echo "--- Launching hecate-web ---"
HECATE_SOCKET_PATH="${HECATE_HOME}/hecate-daemon/sockets/api.sock" \
    "$HECATE_WEB" &

echo ""
echo "=== Local Hecate node running ==="
echo "  Daemon:  http://localhost:4444/health"
echo "  Web:     hecate-web (PID: $!)"
echo "  Stop:    ./scripts/stop-local.sh"
