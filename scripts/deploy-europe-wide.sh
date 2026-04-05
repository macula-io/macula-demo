#!/bin/bash
# Deploy Europe-wide relay identities to box-linode-amsterdam.
#
# Steps:
#   1. Generate identity string with IPv6
#   2. Create DNS AAAA records for new hostnames (via Linode API)
#   3. Update the relay config on the Amsterdam box
#   4. Restart the relay container
#
# Prerequisites:
#   - LINODE_MACULA_IO_DNS_ONLY_TOKEN set
#   - SSH access to box-linode-amsterdam.macula.io
#
# Usage:
#   ./scripts/deploy-europe-wide.sh          # Full deploy
#   ./scripts/deploy-europe-wide.sh dns-only # Only create DNS records
#   ./scripts/deploy-europe-wide.sh dry-run  # Print what would happen

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOX_HOST="box-linode-amsterdam.macula.io"
BOX_SSH="root@${BOX_HOST}"
IPV6_PREFIX="2600:3c0e:e001:ec"
LINODE_TOKEN="${LINODE_MACULA_IO_DNS_ONLY_TOKEN:?Set LINODE_MACULA_IO_DNS_ONLY_TOKEN}"
DOMAIN_ID=""  # Will be looked up
MODE="${1:-deploy}"

echo "=== Europe-Wide Relay Deployment ==="
echo "Box: ${BOX_HOST}"
echo "IPv6 prefix: ${IPV6_PREFIX}::/64"
echo "Mode: ${MODE}"
echo ""

# ── Step 1: Generate identities ──────────────────────────────────
echo "Generating identities..."
IDENTITIES=$(bash "${SCRIPT_DIR}/generate-europe-wide.sh" --prefix "${IPV6_PREFIX}")
IDENTITY_COUNT=$(echo "${IDENTITIES}" | tr ',' '\n' | wc -l)
echo "Generated ${IDENTITY_COUNT} identities"

if [ "${MODE}" = "dry-run" ]; then
  echo ""
  echo "Would create DNS AAAA records for:"
  echo "${IDENTITIES}" | tr ',' '\n' | while IFS='/' read -r host city country lat lng ipv6; do
    echo "  ${host} → ${ipv6}"
  done
  echo ""
  echo "Would update MACULA_RELAY_IDENTITIES on ${BOX_HOST}"
  exit 0
fi

# ── Step 2: Look up Linode domain ID ─────────────────────────────
echo "Looking up macula.io domain ID..."
DOMAIN_ID=$(curl -s -H "Authorization: Bearer ${LINODE_TOKEN}" \
  "https://api.linode.com/v4/domains" \
  | jq -r '.data[] | select(.domain == "macula.io") | .id')

if [ -z "${DOMAIN_ID}" ]; then
  echo "ERROR: Could not find macula.io domain"
  exit 1
fi
echo "Domain ID: ${DOMAIN_ID}"

# ── Step 3: Create DNS AAAA records ──────────────────────────────
echo "Creating DNS AAAA records..."
echo "${IDENTITIES}" | tr ',' '\n' | while IFS='/' read -r host city country lat lng ipv6; do
  # Extract subdomain (relay-xx-city from relay-xx-city.macula.io)
  subdomain="${host%.macula.io}"

  if [ "${MODE}" = "dns-only" ] || [ "${MODE}" = "deploy" ]; then
    # Check if record already exists
    existing=$(curl -s -H "Authorization: Bearer ${LINODE_TOKEN}" \
      "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
      | jq -r ".data[] | select(.name == \"${subdomain}\" and .type == \"AAAA\") | .id")

    if [ -n "${existing}" ]; then
      echo "  SKIP ${subdomain} (exists)"
    else
      curl -s -X POST \
        -H "Authorization: Bearer ${LINODE_TOKEN}" \
        -H "Content-Type: application/json" \
        "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
        -d "{\"type\":\"AAAA\",\"name\":\"${subdomain}\",\"target\":\"${ipv6}\",\"ttl_sec\":300}" \
        > /dev/null
      echo "  CREATED ${subdomain} → ${ipv6}"
    fi
  fi
done

if [ "${MODE}" = "dns-only" ]; then
  echo "DNS records created. Run without dns-only to deploy to box."
  exit 0
fi

# ── Step 4: Update relay config ──────────────────────────────────
echo ""
echo "Updating relay config on ${BOX_HOST}..."

# Write identities to a temp file, SCP to box, update compose env
TMPFILE=$(mktemp)
echo "MACULA_RELAY_IDENTITIES=${IDENTITIES}" > "${TMPFILE}"

scp "${TMPFILE}" "${BOX_SSH}:/tmp/relay-identities.env"
rm "${TMPFILE}"

# Update the .env file on the box
ssh "${BOX_SSH}" bash <<'REMOTE'
cd /root/macula-relay-compose || cd /root/relay || exit 1

# Remove old MACULA_RELAY_IDENTITIES line
sed -i '/^MACULA_RELAY_IDENTITIES=/d' .env 2>/dev/null || true

# Add new one
cat /tmp/relay-identities.env >> .env
rm /tmp/relay-identities.env

echo "Updated .env with new identities"
REMOTE

# ── Step 5: Restart relay ────────────────────────────────────────
echo "Restarting relay container..."
ssh "${BOX_SSH}" "cd /root/macula-relay-compose && docker compose pull relay && docker compose up -d relay" \
  || ssh "${BOX_SSH}" "cd /root/relay && docker compose pull relay && docker compose up -d relay"

echo ""
echo "=== Done ==="
echo "Deployed ${IDENTITY_COUNT} identities to ${BOX_HOST}"
echo "DNS propagation may take 5-10 minutes"
echo "Verify: curl https://${BOX_HOST}/status | jq '.topology.self_relays | length'"
