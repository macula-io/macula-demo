#!/bin/bash
# Deploy stub daemon instances to beam cluster nodes.
#
# Usage:
#   ./scripts/deploy-stubs.sh           # Deploy to all nodes
#   ./scripts/deploy-stubs.sh beam01    # Deploy to one node
#   ./scripts/deploy-stubs.sh --stop    # Stop all stubs
#   ./scripts/deploy-stubs.sh --status  # Check stub status
#
# Prerequisites:
#   - SSH access to beam0{0..3}.lab (ssh rl@beamXX.lab)
#   - Docker/Podman on each beam node
#   - Primary daemon already deployed via daemon/docker-compose.yml

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STUBS_DIR="${SCRIPT_DIR}/daemon/stubs"
NODES=("beam00" "beam01" "beam02" "beam03")
REMOTE_DIR="/home/rl/.hecate/compose-stubs"

deploy_node() {
    local node="$1"
    local host="${node}.lab"
    local compose_file="docker-compose.${node}.yml"
    local geo_env="primary-geo.env.${node}"

    if [ ! -f "${STUBS_DIR}/${compose_file}" ]; then
        echo "[${node}] No compose file found, skipping"
        return
    fi

    echo "[${node}] Deploying stubs to ${host}..."

    # Create remote directory
    ssh "rl@${host}" "mkdir -p ${REMOTE_DIR}"

    # Copy compose file
    scp "${STUBS_DIR}/${compose_file}" "rl@${host}:${REMOTE_DIR}/docker-compose.yml"

    # Copy geo env for primary daemon
    if [ -f "${STUBS_DIR}/${geo_env}" ]; then
        scp "${STUBS_DIR}/${geo_env}" "rl@${host}:${REMOTE_DIR}/primary-geo.env"

        # Append geo env to primary daemon's env file (if not already present)
        ssh "rl@${host}" "
            if ! grep -q HECATE_GEO_CITY /home/rl/.hecate/compose/hecate-daemon.env 2>/dev/null; then
                echo '' >> /home/rl/.hecate/compose/hecate-daemon.env
                cat ${REMOTE_DIR}/primary-geo.env >> /home/rl/.hecate/compose/hecate-daemon.env
                echo '[${node}] Added geo identity to primary daemon'
                cd /home/rl/.hecate/compose && docker compose restart hecate-daemon
            fi
        "
    fi

    # Start stubs
    ssh "rl@${host}" "cd ${REMOTE_DIR} && docker compose pull && docker compose up -d"

    echo "[${node}] Done"
}

stop_node() {
    local node="$1"
    local host="${node}.lab"
    echo "[${node}] Stopping stubs on ${host}..."
    ssh "rl@${host}" "cd ${REMOTE_DIR} && docker compose down 2>/dev/null || true"
}

status_node() {
    local node="$1"
    local host="${node}.lab"
    echo "=== ${node} ==="
    ssh "rl@${host}" "cd ${REMOTE_DIR} && docker compose ps 2>/dev/null || echo 'No stubs deployed'"
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
        echo "All stubs deployed. 15 daemon nodes across 4 beam hosts."
        echo "Check topology at https://macula.io/topology"
        ;;
    beam0[0-3])
        deploy_node "$1"
        ;;
    *)
        echo "Usage: $0 [beam00|beam01|beam02|beam03|all|--stop|--status]"
        exit 1
        ;;
esac
