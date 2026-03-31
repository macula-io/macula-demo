#!/usr/bin/env bash
#
# Stop the local attended Hecate node.
#
# Usage:
#   ./scripts/stop-local.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCAL_DIR="${REPO_DIR}/local"

# ── Detect container runtime ──────────────────────────────────────
if command -v podman &>/dev/null; then
    COMPOSE="podman compose"
elif command -v docker &>/dev/null; then
    COMPOSE="docker compose"
else
    echo "ERROR: Neither docker nor podman found" >&2
    exit 1
fi

echo "=== Stopping local Hecate node ==="

# ── Stop hecate-web ───────────────────────────────────────────────
if pgrep -x hecate-web &>/dev/null; then
    echo "--- Stopping hecate-web ---"
    pkill -x hecate-web || true
fi

# ── Stop daemon ───────────────────────────────────────────────────
echo "--- Stopping hecate-daemon ---"
cd "$LOCAL_DIR"
$COMPOSE down

echo "=== Stopped ==="
