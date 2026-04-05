#!/bin/bash
# Deploy per-identity IPv6 addresses on both Hetzner relay boxes.
#
# Steps per box:
#   1. Add IPv6 addresses via ip addr add
#   2. Create systemd service to persist addresses across reboots
#   3. Create DNS AAAA records for each hostname
#   4. Update relay config with IPv6-enabled identities
#   5. Restart relay
#
# Usage:
#   ./scripts/deploy-ipv6-hetzner.sh          # Full deploy
#   ./scripts/deploy-ipv6-hetzner.sh dns-only # Only create DNS records

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINODE_TOKEN="${LINODE_MACULA_IO_DNS_ONLY_TOKEN:?Set LINODE_MACULA_IO_DNS_ONLY_TOKEN}"
SSH_PASS="K!llB@ll2601"
MODE="${1:-deploy}"

# Box configs
declare -A BOXES=(
  [nuremberg]="box-hetzner-nuremberg.macula.io|2a01:4f8:1c1f:8ab8|eth0"
  [helsinki]="box-hetzner-helsinki.macula.io|2a01:4f9:c014:4259|eth0"
)

echo "=== Hetzner Per-Identity IPv6 Deployment ==="

# ── Step 1: Look up Linode domain ID for DNS ─────────────────────
echo "Looking up macula.io domain ID..."
DOMAIN_ID=$(curl -s -H "Authorization: Bearer ${LINODE_TOKEN}" \
  "https://api.linode.com/v4/domains" \
  | jq -r '.data[] | select(.domain == "macula.io") | .id')
echo "Domain ID: ${DOMAIN_ID}"

for box_name in nuremberg helsinki; do
  IFS='|' read -r HOST PREFIX IFACE <<< "${BOXES[$box_name]}"
  echo ""
  echo "=== ${box_name} (${HOST}) ==="
  echo "  IPv6 prefix: ${PREFIX}::/64"

  # Generate identities with IPv6
  IDENTITIES=$(bash "${SCRIPT_DIR}/generate-europe-150.sh" "${box_name}")
  IDENTITY_COUNT=$(echo "${IDENTITIES}" | tr ',' '\n' | wc -l)
  echo "  Identities: ${IDENTITY_COUNT}"

  # ── Add IPv6 addresses on the box ────────────────────────────
  if [ "${MODE}" != "dns-only" ]; then
    echo "  Adding IPv6 addresses..."

    # Build ip addr add commands
    ADDR_CMDS=""
    echo "${IDENTITIES}" | tr ',' '\n' | while IFS='/' read -r host city country lat lng ipv6; do
      echo "ip -6 addr add ${ipv6}/64 dev ${IFACE} 2>/dev/null || true"
    done > /tmp/add-ipv6-${box_name}.sh

    # Also create systemd service for persistence
    cat > /tmp/macula-ipv6-${box_name}.service << SVCEOF
[Unit]
Description=Macula per-identity IPv6 addresses
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/macula-add-ipv6.sh

[Install]
WantedBy=multi-user.target
SVCEOF

    # Upload and execute
    sshpass -p "${SSH_PASS}" scp -o StrictHostKeyChecking=no \
      /tmp/add-ipv6-${box_name}.sh "root@${HOST}:/usr/local/bin/macula-add-ipv6.sh"
    sshpass -p "${SSH_PASS}" scp -o StrictHostKeyChecking=no \
      /tmp/macula-ipv6-${box_name}.service "root@${HOST}:/etc/systemd/system/macula-ipv6.service"

    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no "root@${HOST}" bash << REMOTE
chmod +x /usr/local/bin/macula-add-ipv6.sh
bash /usr/local/bin/macula-add-ipv6.sh
systemctl daemon-reload
systemctl enable macula-ipv6.service
echo "  IPv6 addresses added: \$(ip -6 addr show dev ${IFACE} | grep -c 'inet6.*global') total"
REMOTE
  fi

  # ── Create DNS AAAA records ──────────────────────────────────
  echo "  Creating DNS AAAA records..."
  echo "${IDENTITIES}" | tr ',' '\n' | while IFS='/' read -r host city country lat lng ipv6; do
    subdomain="${host%.macula.io}"

    existing=$(curl -s -H "Authorization: Bearer ${LINODE_TOKEN}" \
      "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
      | jq -r ".data[] | select(.name == \"${subdomain}\" and .type == \"AAAA\") | .id")

    if [ -n "${existing}" ]; then
      # Update existing record
      curl -s -X PUT \
        -H "Authorization: Bearer ${LINODE_TOKEN}" \
        -H "Content-Type: application/json" \
        "https://api.linode.com/v4/domains/${DOMAIN_ID}/records/${existing}" \
        -d "{\"target\":\"${ipv6}\"}" > /dev/null
      echo "    UPDATED ${subdomain} → ${ipv6}"
    else
      curl -s -X POST \
        -H "Authorization: Bearer ${LINODE_TOKEN}" \
        -H "Content-Type: application/json" \
        "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
        -d "{\"type\":\"AAAA\",\"name\":\"${subdomain}\",\"target\":\"${ipv6}\",\"ttl_sec\":300}" \
        > /dev/null
      echo "    CREATED ${subdomain} → ${ipv6}"
    fi
  done

  # ── Update relay config ──────────────────────────────────────
  if [ "${MODE}" != "dns-only" ]; then
    echo "  Updating relay config..."
    echo "MACULA_RELAY_IDENTITIES=${IDENTITIES}" > /tmp/relay-ids-${box_name}.env

    sshpass -p "${SSH_PASS}" scp -o StrictHostKeyChecking=no \
      /tmp/relay-ids-${box_name}.env "root@${HOST}:/tmp/relay-ids.env"

    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no "root@${HOST}" bash << 'REMOTE'
cd /root/macula-realm-compose
sed -i '/^MACULA_RELAY_IDENTITIES=/d' .env
cat /tmp/relay-ids.env >> .env
rm /tmp/relay-ids.env
echo "  Config updated"
docker compose -f docker-compose-relay.yml up -d relay 2>&1 | tail -3
REMOTE
  fi

  echo "  Done: ${box_name}"
done

echo ""
echo "=== Deployment complete ==="
echo "DNS propagation: 5-10 minutes"
echo "Verify: curl -s https://box-hetzner-nuremberg.macula.io/status | python3 -c \"import sys,json; print(json.load(sys.stdin)['topology']['self_relays'][0])\""
