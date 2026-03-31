#!/bin/bash
# Setup GitHub Container Registry authentication
#
# Usage: ./scripts/setup-ghcr-auth.sh
#
# Reads GITHUB_USER and GITHUB_MACULA_REALM_REGISTRY_PAT from .env
# and creates docker-config.json for Watchtower + logs in locally

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REALM_DIR="${SCRIPT_DIR}/.."

if [ ! -f "${REALM_DIR}/.env" ]; then
    echo "ERROR: .env file not found in ${REALM_DIR}"
    echo "Copy .env.example to .env and fill in values first"
    exit 1
fi

set -a
source "${REALM_DIR}/.env"
set +a

: "${GITHUB_USER:?GITHUB_USER not set in .env}"
: "${GITHUB_MACULA_REALM_REGISTRY_PAT:?GITHUB_MACULA_REALM_REGISTRY_PAT not set in .env}"

AUTH=$(echo -n "${GITHUB_USER}:${GITHUB_MACULA_REALM_REGISTRY_PAT}" | base64 -w0)

cat > "${REALM_DIR}/docker-config.json" << EOF
{
  "auths": {
    "ghcr.io": {
      "auth": "${AUTH}"
    }
  }
}
EOF

echo "Created ${REALM_DIR}/docker-config.json"

echo "${GITHUB_MACULA_REALM_REGISTRY_PAT}" | docker login ghcr.io -u "${GITHUB_USER}" --password-stdin

echo "Both local Docker and Watchtower are configured to pull from ghcr.io"
