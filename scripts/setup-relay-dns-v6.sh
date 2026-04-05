#!/bin/bash
# Create DNS records for relay boxes and relay identities.
#
# Creates:
#   1. A + AAAA records for physical boxes (box-hetzner-nuremberg.macula.io etc.)
#   2. AAAA records for each relay identity (relay-be-brussels.macula.io → unique IPv6)
#
# Uses Linode DNS API (domain: macula.io).
#
# Usage:
#   ./scripts/setup-relay-dns-v6.sh [--dry-run]
#
# Prerequisites:
#   - LINODE_DNS_API_TOKEN env var set
#   - assign-relay-ipv6.sh has been run (identities have IPv6 addresses)

set -euo pipefail

DOMAIN_ID=1303878
TOKEN="${LINODE_DNS_API_TOKEN:?Set LINODE_DNS_API_TOKEN env var}"
DRY_RUN="${1:-}"
API="https://api.linode.com/v4/domains/${DOMAIN_ID}/records"

# ── Box definitions ───────────────────────────────────────────────
# Format: DNS_NAME|IPV4|IPV6_PRIMARY|SSH_HOST|IPV6_PREFIX
BOXES=(
  "box-hetzner-nuremberg|91.98.238.177|2a01:4f8:1c1f:8ab8::1|root@91.98.238.177|2a01:4f8:1c1f:8ab8"
  "box-hetzner-helsinki|95.216.141.48|2a01:4f9:c014:4259::1|root@95.216.141.48|2a01:4f9:c014:4259"
  "box-linode-frankfurt|172.104.143.73|2a01:7e01::f03c:94ff:fe22:719e|root@172.104.143.73|"
  "box-linode-amsterdam|172.235.174.211|2600:3c0e:e001:ec::1|root@172.235.174.211|2600:3c0e:e001:ec"
)

# ── DNS helper functions ──────────────────────────────────────────

# Find a record by name and type, return "ID|TARGET" or "NONE"
find_record() {
  local name="$1" rtype="$2"
  curl -s -H "Authorization: Bearer ${TOKEN}" "${API}?page_size=500" \
    | python3 -c "
import json,sys
data = json.load(sys.stdin).get('data',[])
matches = [r for r in data if r['name']=='${name}' and r['type']=='${rtype}']
if matches:
    print(f\"{matches[0]['id']}|{matches[0]['target']}\")
else:
    print('NONE')
" 2>/dev/null
}

# Create or update a DNS record
upsert_record() {
  local name="$1" rtype="$2" target="$3"

  if [ "${DRY_RUN}" = "--dry-run" ]; then
    echo "  [dry-run] ${name}.macula.io ${rtype} → ${target}"
    return
  fi

  local existing
  existing=$(find_record "${name}" "${rtype}")

  if [ "${existing}" = "NONE" ]; then
    echo "  [create] ${name}.macula.io ${rtype} → ${target}"
    curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/json" "${API}" \
      -d "{\"type\": \"${rtype}\", \"name\": \"${name}\", \"target\": \"${target}\", \"ttl_sec\": 300}" > /dev/null
  else
    IFS='|' read -r record_id current_target <<< "${existing}"
    if [ "${current_target}" = "${target}" ]; then
      echo "  [skip]   ${name}.macula.io ${rtype} → ${target} (exists)"
    else
      echo "  [update] ${name}.macula.io ${rtype} → ${target} (was ${current_target})"
      curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" "${API}/${record_id}" \
        -d "{\"target\": \"${target}\"}" > /dev/null
    fi
  fi
}

# ── Step 1: Box-level DNS records ─────────────────────────────────
echo "=== Step 1: Physical box DNS records ==="
echo ""

for box_def in "${BOXES[@]}"; do
  IFS='|' read -r DNS_NAME IPV4 IPV6 SSH_HOST IPV6_PREFIX <<< "${box_def}"

  echo "  ${DNS_NAME}.macula.io:"
  upsert_record "${DNS_NAME}" "A" "${IPV4}"
  upsert_record "${DNS_NAME}" "AAAA" "${IPV6}"
done

# ── Step 2: Relay identity AAAA records ───────────────────────────
echo ""
echo "=== Step 2: Relay identity AAAA records ==="
echo ""

CREATED=0
SKIPPED=0
UPDATED=0

for box_def in "${BOXES[@]}"; do
  IFS='|' read -r DNS_NAME IPV4 IPV6 SSH_HOST IPV6_PREFIX <<< "${box_def}"

  # Skip boxes without relay identities (e.g., Linode realm server)
  if [ -z "${IPV6_PREFIX}" ]; then
    echo "  [skip] ${DNS_NAME} — no relay identity prefix (realm server)"
    continue
  fi

  echo "  ${DNS_NAME} — fetching identity list..."

  # Get identity hostnames from the running relay
  IDENTITIES=$(ssh -o StrictHostKeyChecking=no "${SSH_HOST}" \
    "docker exec macula-relay printenv MACULA_RELAY_IDENTITIES 2>/dev/null || echo ''" 2>/dev/null)

  if [ -z "${IDENTITIES}" ]; then
    echo "  [skip] No identities found on ${DNS_NAME}"
    continue
  fi

  HOSTNAMES=$(echo "${IDENTITIES}" | tr ',' '\n' | cut -d: -f1)
  TOTAL=$(echo "${HOSTNAMES}" | wc -l)
  echo "  ${DNS_NAME}: ${TOTAL} identities"

  INDEX=256  # Start at ::100
  while IFS= read -r hostname; do
    HEX_INDEX=$(printf '%x' ${INDEX})
    ADDR="${IPV6_PREFIX}::${HEX_INDEX}"

    # Strip .macula.io suffix for the DNS record name
    RECORD_NAME="${hostname%.macula.io}"

    upsert_record "${RECORD_NAME}" "AAAA" "${ADDR}"
    INDEX=$((INDEX + 1))
  done <<< "${HOSTNAMES}"

  echo ""
done

echo ""
echo "=== Done ==="
echo "DNS propagation: ~5 minutes (TTL 300s)"
echo ""
echo "Verify with:"
echo "  dig AAAA box-hetzner-nuremberg.macula.io"
echo "  dig AAAA relay-be-brussels.macula.io"
