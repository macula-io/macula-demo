#!/bin/bash
# Deploy stub instances to beam cluster nodes.
#
# Manages two sets of compose files per node:
#   - daemon stubs (docker-compose.beamXX.yml) — full hecate-daemon instances
#   - lightweight stubs (docker-compose.stubs-beamXX.yml) — hecate-stub instances
#
# Usage:
#   ./scripts/deploy-stubs.sh           # Deploy all (daemon + lightweight)
#   ./scripts/deploy-stubs.sh beam01    # Deploy to one node
#   ./scripts/deploy-stubs.sh --stop    # Stop all stubs
#   ./scripts/deploy-stubs.sh --status  # Check stub status

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STUBS_DIR="${SCRIPT_DIR}/daemon/stubs"
NODES=("beam00" "beam01" "beam02" "beam03")
DAEMON_STUBS_DIR="/home/rl/.hecate/compose-stubs"
LIGHT_STUBS_DIR="/home/rl/.hecate/compose-light-stubs"

deploy_node() {
    local node="$1"
    local host="${node}.lab"

    echo "[${node}] Deploying to ${host}..."
    ssh "rl@${host}" "mkdir -p ${DAEMON_STUBS_DIR} ${LIGHT_STUBS_DIR}"

    # Deploy daemon stubs (full hecate-daemon instances)
    local daemon_compose="docker-compose.${node}.yml"
    if [ -f "${STUBS_DIR}/${daemon_compose}" ]; then
        scp "${STUBS_DIR}/${daemon_compose}" "rl@${host}:${DAEMON_STUBS_DIR}/docker-compose.yml"
        ssh "rl@${host}" "cd ${DAEMON_STUBS_DIR} && docker compose pull -q && docker compose up -d"
        echo "[${node}] Daemon stubs up"
    fi

    # Deploy lightweight stubs (hecate-stub instances)
    local light_compose="docker-compose.stubs-${node}.yml"
    if [ -f "${STUBS_DIR}/${light_compose}" ]; then
        scp "${STUBS_DIR}/${light_compose}" "rl@${host}:${LIGHT_STUBS_DIR}/docker-compose.yml"
        ssh "rl@${host}" "cd ${LIGHT_STUBS_DIR} && docker compose pull -q && docker compose up -d"
        echo "[${node}] Lightweight stubs up"
    fi

    # Ensure primary daemon has geo env
    local geo_env="primary-geo.env.${node}"
    if [ -f "${STUBS_DIR}/${geo_env}" ]; then
        scp "${STUBS_DIR}/${geo_env}" "rl@${host}:${DAEMON_STUBS_DIR}/primary-geo.env"
        ssh "rl@${host}" "
            GITOPS_ENV=\$HOME/.hecate/gitops/system/hecate-daemon.env
            if [ -f \"\$GITOPS_ENV\" ] && ! grep -q HECATE_GEO_CITY \"\$GITOPS_ENV\" 2>/dev/null; then
                cat ${DAEMON_STUBS_DIR}/primary-geo.env >> \"\$GITOPS_ENV\"
                cd \$HOME/.hecate/compose && docker compose up -d --force-recreate hecate-daemon
                echo '  Added geo to primary daemon'
            fi
        "
    fi

    echo "[${node}] Done"
}

stop_node() {
    local node="$1"
    local host="${node}.lab"
    echo "[${node}] Stopping stubs on ${host}..."
    ssh "rl@${host}" "
        cd ${DAEMON_STUBS_DIR} && docker compose down 2>/dev/null || true
        cd ${LIGHT_STUBS_DIR} && docker compose down 2>/dev/null || true
    "
}

status_node() {
    local node="$1"
    local host="${node}.lab"
    echo "=== ${node} ==="
    ssh "rl@${host}" "
        echo '--- daemon stubs ---'
        cd ${DAEMON_STUBS_DIR} && docker compose ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || echo '  (none)'
        echo '--- lightweight stubs ---'
        cd ${LIGHT_STUBS_DIR} && docker compose ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || echo '  (none)'
    "
    echo ""
}

case "${1:-all}" in
    --stop)
        for node in "${NODES[@]}"; do stop_node "$node"; done
        ;;
    --status)
        for node in "${NODES[@]}"; do status_node "$node"; done
        ;;
    all)
        for node in "${NODES[@]}"; do deploy_node "$node"; done
        echo ""
        echo "All stubs deployed. Check topology at https://macula.io/topology"
        ;;
    beam0[0-3])
        deploy_node "$1"
        ;;
    *)
        echo "Usage: $0 [beam00|beam01|beam02|beam03|all|--stop|--status]"
        exit 1
        ;;
esac
