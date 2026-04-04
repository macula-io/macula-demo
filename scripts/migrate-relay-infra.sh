#!/bin/bash
# Migrate relay infrastructure:
# 1. Clean up old DNS (relayNN names, shared-IPv4 A records for identities)
# 2. Create box-* DNS records for all physical boxes
# 3. Convert Hetzner identity configs to slash format
# 4. Redistribute identities (remove BeNeLux from Nuremberg — now on Amsterdam)
# 5. Pull new image and restart Hetzner relays
#
# Usage: ./scripts/migrate-relay-infra.sh [--dry-run]

set -euo pipefail

DRY_RUN="${1:-}"
LINODE_TOKEN="${LINODE_DNS_API_TOKEN:?Set LINODE_DNS_API_TOKEN env var}"
DOMAIN_ID=1303878
API="https://api.linode.com/v4/domains/${DOMAIN_ID}/records"

# ── Box definitions ───────────────────────────────────────────────
# Physical boxes with new descriptive names
declare -A BOX_IPV4=(
  [box-hetzner-nuremberg]="91.98.238.177"
  [box-hetzner-helsinki]="95.216.141.48"
  [box-linode-frankfurt]="172.104.143.73"
  [box-linode-amsterdam]="172.235.174.211"
)
declare -A BOX_IPV6=(
  [box-hetzner-nuremberg]="2a01:4f8:1c1f:8ab8::1"
  [box-hetzner-helsinki]="2a01:4f9:c014:4259::1"
  [box-linode-frankfurt]="2a01:7e01::f03c:94ff:fe22:719e"
  [box-linode-amsterdam]="2600:3c0e:e001:ec::1"
)

# ── Nuremberg identities (non-BeNeLux EU cities) ──────────────────
# Central + Southern + Western Europe — all in slash format, no IPv6 bind yet
NUREMBERG_IDENTITIES=$(cat <<'IDENT'
relay-de-nuremberg.macula.io/Nuremberg/DE/49.4521/11.0767,relay-de-berlin.macula.io/Berlin/DE/52.5200/13.4050,relay-de-munich.macula.io/Munich/DE/48.1351/11.5820,relay-de-frankfurt.macula.io/Frankfurt/DE/50.1109/8.6821,relay-de-hamburg.macula.io/Hamburg/DE/53.5511/9.9937,relay-de-cologne.macula.io/Cologne/DE/50.9375/6.9603,relay-fr-paris.macula.io/Paris/FR/48.8566/2.3522,relay-fr-lyon.macula.io/Lyon/FR/45.7640/4.8357,relay-fr-marseille.macula.io/Marseille/FR/43.2965/5.3698,relay-uk-london.macula.io/London/UK/51.5074/-0.1278,relay-uk-manchester.macula.io/Manchester/UK/53.4808/-2.2426,relay-uk-edinburgh.macula.io/Edinburgh/UK/55.9533/-3.1883,relay-ie-dublin.macula.io/Dublin/IE/53.3498/-6.2603,relay-es-madrid.macula.io/Madrid/ES/40.4168/-3.7038,relay-es-barcelona.macula.io/Barcelona/ES/41.3874/2.1686,relay-pt-lisbon.macula.io/Lisbon/PT/38.7223/-9.1393,relay-it-rome.macula.io/Rome/IT/41.9028/12.4964,relay-it-milan.macula.io/Milan/IT/45.4642/9.1900,relay-ch-zurich.macula.io/Zurich/CH/47.3769/8.5417,relay-ch-geneva.macula.io/Geneva/CH/46.2044/6.1432,relay-at-vienna.macula.io/Vienna/AT/48.2082/16.3738,relay-cz-prague.macula.io/Prague/CZ/50.0755/14.4378,relay-hu-budapest.macula.io/Budapest/HU/47.4979/19.0402,relay-sk-bratislava.macula.io/Bratislava/SK/48.1486/17.1077,relay-si-ljubljana.macula.io/Ljubljana/SI/46.0569/14.5058,relay-hr-zagreb.macula.io/Zagreb/HR/45.8150/15.9819,relay-gr-athens.macula.io/Athens/GR/37.9838/23.7275,relay-ro-bucharest.macula.io/Bucharest/RO/44.4268/26.1025,relay-bg-sofia.macula.io/Sofia/BG/42.6977/23.3219,relay-rs-belgrade.macula.io/Belgrade/RS/44.7866/20.4489
IDENT
)

# ── Helsinki identities (Nordic + Baltic + Eastern EU) ────────────
HELSINKI_IDENTITIES=$(cat <<'IDENT'
relay-fi-helsinki.macula.io/Helsinki/FI/60.1699/24.9384,relay-fi-tampere.macula.io/Tampere/FI/61.4978/23.7610,relay-fi-turku.macula.io/Turku/FI/60.4518/22.2666,relay-se-stockholm.macula.io/Stockholm/SE/59.3293/18.0686,relay-se-gothenburg.macula.io/Gothenburg/SE/57.7089/11.9746,relay-se-malmo.macula.io/Malmo/SE/55.6049/13.0038,relay-no-oslo.macula.io/Oslo/NO/59.9139/10.7522,relay-no-bergen.macula.io/Bergen/NO/60.3913/5.3221,relay-dk-copenhagen.macula.io/Copenhagen/DK/55.6761/12.5683,relay-dk-aarhus.macula.io/Aarhus/DK/56.1629/10.2039,relay-ee-tallinn.macula.io/Tallinn/EE/59.4370/24.7536,relay-lv-riga.macula.io/Riga/LV/56.9496/24.1052,relay-lt-vilnius.macula.io/Vilnius/LT/54.6872/25.2797,relay-pl-warsaw.macula.io/Warsaw/PL/52.2297/21.0122,relay-pl-krakow.macula.io/Krakow/PL/50.0647/19.9450,relay-pl-gdansk.macula.io/Gdansk/PL/54.3520/18.6466,relay-pl-wroclaw.macula.io/Wroclaw/PL/51.1079/17.0385,relay-is-reykjavik.macula.io/Reykjavik/IS/64.1466/-21.9426
IDENT
)

echo "=== Relay Infrastructure Migration ==="
echo ""

# ═══════════════════════════════════════════════════════════════════
# Step 1: Delete old DNS records
# ═══════════════════════════════════════════════════════════════════
echo "--- Step 1: Delete old DNS records ---"

# Get all records
ALL_RECORDS=$(curl -s -H "Authorization: Bearer ${LINODE_TOKEN}" "${API}?page_size=500")

# Find records to delete:
# - relay00/01/02.macula.io A records
# - All relay-* A records (old shared-IPv4 entries)
DELETE_IDS=$(echo "${ALL_RECORDS}" | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
to_delete = []
for r in data:
    name = r['name']
    rtype = r['type']
    rid = r['id']
    # Delete relayNN A records
    if name in ('relay00', 'relay01', 'relay02', 'relay03') and rtype == 'A':
        to_delete.append((rid, name, rtype, r['target']))
    # Delete all relay-* A records (old shared-IPv4)
    elif name.startswith('relay-') and rtype == 'A':
        to_delete.append((rid, name, rtype, r['target']))
for rid, name, rtype, target in sorted(to_delete, key=lambda x: x[1]):
    print(f'{rid}|{name}|{rtype}|{target}')
" 2>/dev/null)

DELETE_COUNT=$(echo "${DELETE_IDS}" | grep -c '|' || echo 0)
echo "  Found ${DELETE_COUNT} old records to delete"

if [ "${DRY_RUN}" = "--dry-run" ]; then
  echo "${DELETE_IDS}" | head -5 | while IFS='|' read -r id name rtype target; do
    echo "  [dry-run] DELETE ${name}.macula.io ${rtype} ${target}"
  done
  echo "  ... (${DELETE_COUNT} total)"
else
  echo "${DELETE_IDS}" | while IFS='|' read -r id name rtype target; do
    [ -z "${id}" ] && continue
    curl -s -X DELETE -H "Authorization: Bearer ${LINODE_TOKEN}" "${API}/${id}" > /dev/null
  done
  echo "  Deleted ${DELETE_COUNT} records"
fi

# ═══════════════════════════════════════════════════════════════════
# Step 2: Create/update box-* DNS records
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "--- Step 2: Create box-* DNS records ---"

for box in box-hetzner-nuremberg box-hetzner-helsinki box-linode-frankfurt box-linode-amsterdam; do
  ipv4="${BOX_IPV4[$box]}"
  ipv6="${BOX_IPV6[$box]}"

  if [ "${DRY_RUN}" = "--dry-run" ]; then
    echo "  [dry-run] ${box}.macula.io A ${ipv4}"
    echo "  [dry-run] ${box}.macula.io AAAA ${ipv6}"
    continue
  fi

  # Check if A record exists
  EXISTING_A=$(echo "${ALL_RECORDS}" | python3 -c "
import json,sys
data=json.load(sys.stdin).get('data',[])
m=[r for r in data if r['name']=='${box}' and r['type']=='A']
print(m[0]['id'] if m else 'NONE')
" 2>/dev/null)

  if [ "${EXISTING_A}" = "NONE" ]; then
    curl -s -X POST -H "Authorization: Bearer ${LINODE_TOKEN}" -H "Content-Type: application/json" \
      "${API}" -d "{\"type\":\"A\",\"name\":\"${box}\",\"target\":\"${ipv4}\",\"ttl_sec\":300}" > /dev/null
    echo "  [create] ${box}.macula.io A ${ipv4}"
  else
    echo "  [exists] ${box}.macula.io A ${ipv4}"
  fi

  # Check if AAAA record exists
  EXISTING_AAAA=$(echo "${ALL_RECORDS}" | python3 -c "
import json,sys
data=json.load(sys.stdin).get('data',[])
m=[r for r in data if r['name']=='${box}' and r['type']=='AAAA']
print(m[0]['id'] if m else 'NONE')
" 2>/dev/null)

  if [ "${EXISTING_AAAA}" = "NONE" ]; then
    curl -s -X POST -H "Authorization: Bearer ${LINODE_TOKEN}" -H "Content-Type: application/json" \
      "${API}" -d "{\"type\":\"AAAA\",\"name\":\"${box}\",\"target\":\"${ipv6}\",\"ttl_sec\":300}" > /dev/null
    echo "  [create] ${box}.macula.io AAAA ${ipv6}"
  else
    echo "  [exists] ${box}.macula.io AAAA ${ipv6}"
  fi
done

# ═══════════════════════════════════════════════════════════════════
# Step 3: Update Hetzner box configs (slash format, new identities)
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "--- Step 3: Update Hetzner configs ---"

if [ "${DRY_RUN}" = "--dry-run" ]; then
  echo "  [dry-run] box-hetzner-nuremberg: 30 Central/Southern EU identities (slash format)"
  echo "  [dry-run] box-hetzner-helsinki: 18 Nordic/Baltic/Eastern EU identities (slash format)"
else
  # Nuremberg
  ADMIN_TOKEN=$(ssh -o StrictHostKeyChecking=no root@91.98.238.177 "grep MACULA_ADMIN_TOKEN /root/macula-realm-compose/.env | cut -d= -f2" 2>/dev/null)
  LINODE_DNS=$(ssh -o StrictHostKeyChecking=no root@91.98.238.177 "grep LINODE_DNS_API_TOKEN /root/macula-realm-compose/.env | cut -d= -f2" 2>/dev/null)

  ssh -o StrictHostKeyChecking=no root@91.98.238.177 "cat > /root/macula-realm-compose/.env << EOF
RELAY_HOSTNAME=box-hetzner-nuremberg
MACULA_REALM=io.macula
RELAY_VERSION=main
LINODE_DNS_API_TOKEN=${LINODE_DNS}
MACULA_ADMIN_TOKEN=${ADMIN_TOKEN}
MACULA_RELAYS=https://box-linode-amsterdam.macula.io:4433,https://box-hetzner-helsinki.macula.io:4433
MACULA_RELAY_IDENTITIES=${NUREMBERG_IDENTITIES}
EOF"
  echo "  [updated] box-hetzner-nuremberg: 30 Central/Southern EU identities"

  # Helsinki
  ADMIN_TOKEN_H=$(ssh -o StrictHostKeyChecking=no root@95.216.141.48 "grep MACULA_ADMIN_TOKEN /root/macula-realm-compose/.env | cut -d= -f2" 2>/dev/null)
  LINODE_DNS_H=$(ssh -o StrictHostKeyChecking=no root@95.216.141.48 "grep LINODE_DNS_API_TOKEN /root/macula-realm-compose/.env | cut -d= -f2" 2>/dev/null)

  ssh -o StrictHostKeyChecking=no root@95.216.141.48 "cat > /root/macula-realm-compose/.env << EOF
RELAY_HOSTNAME=box-hetzner-helsinki
MACULA_REALM=io.macula
RELAY_VERSION=main
LINODE_DNS_API_TOKEN=${LINODE_DNS_H}
MACULA_ADMIN_TOKEN=${ADMIN_TOKEN_H}
MACULA_RELAYS=https://box-linode-amsterdam.macula.io:4433,https://box-hetzner-nuremberg.macula.io:4433
MACULA_RELAY_IDENTITIES=${HELSINKI_IDENTITIES}
EOF"
  echo "  [updated] box-hetzner-helsinki: 18 Nordic/Baltic/Eastern EU identities"
fi

# ═══════════════════════════════════════════════════════════════════
# Step 4: Update Caddyfile hostname references
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "--- Step 4: Update Caddy cert symlinks ---"

if [ "${DRY_RUN}" != "--dry-run" ]; then
  # Nuremberg: symlink box-hetzner-nuremberg cert dir to wildcard
  ssh -o StrictHostKeyChecking=no root@91.98.238.177 "
    CERT_DIR=\$(docker volume inspect macula-realm-compose_caddy_data --format '{{.Mountpoint}}')/caddy/certificates/acme-v02.api.letsencrypt.org-directory
    mkdir -p \${CERT_DIR}/box-hetzner-nuremberg.macula.io
    cp \${CERT_DIR}/wildcard_.macula.io/wildcard_.macula.io.crt \${CERT_DIR}/box-hetzner-nuremberg.macula.io/box-hetzner-nuremberg.macula.io.crt 2>/dev/null || true
    cp \${CERT_DIR}/wildcard_.macula.io/wildcard_.macula.io.key \${CERT_DIR}/box-hetzner-nuremberg.macula.io/box-hetzner-nuremberg.macula.io.key 2>/dev/null || true
    echo 'Nuremberg cert ready'
  " 2>/dev/null

  # Helsinki: same
  ssh -o StrictHostKeyChecking=no root@95.216.141.48 "
    CERT_DIR=\$(docker volume inspect macula-realm-compose_caddy_data --format '{{.Mountpoint}}')/caddy/certificates/acme-v02.api.letsencrypt.org-directory
    mkdir -p \${CERT_DIR}/box-hetzner-helsinki.macula.io
    cp \${CERT_DIR}/wildcard_.macula.io/wildcard_.macula.io.crt \${CERT_DIR}/box-hetzner-helsinki.macula.io/box-hetzner-helsinki.macula.io.crt 2>/dev/null || true
    cp \${CERT_DIR}/wildcard_.macula.io/wildcard_.macula.io.key \${CERT_DIR}/box-hetzner-helsinki.macula.io/box-hetzner-helsinki.macula.io.key 2>/dev/null || true
    echo 'Helsinki cert ready'
  " 2>/dev/null
fi

# ═══════════════════════════════════════════════════════════════════
# Step 5: Pull new image and restart
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "--- Step 5: Pull new image and restart ---"

if [ "${DRY_RUN}" = "--dry-run" ]; then
  echo "  [dry-run] Would pull ghcr.io/macula-io/macula-relay:main on both boxes"
  echo "  [dry-run] Would restart relay + watchtower"
else
  for box_info in "root@91.98.238.177|box-hetzner-nuremberg" "root@95.216.141.48|box-hetzner-helsinki"; do
    IFS='|' read -r host name <<< "${box_info}"
    echo "  ${name}: pulling new image..."
    ssh -o StrictHostKeyChecking=no "${host}" "
      cd /root/macula-realm-compose
      docker compose -f docker-compose-relay.yml pull relay 2>&1 | tail -1
      docker compose -f docker-compose-relay.yml up -d relay 2>&1 | tail -1
      docker start macula-watchtower 2>&1
    " 2>/dev/null
    echo "  ${name}: restarted"
  done
fi

# ═══════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "=== Summary ==="
echo ""
echo "Relay boxes:"
echo "  box-hetzner-nuremberg  (91.98.238.177)   — 30 Central/Southern EU identities"
echo "  box-hetzner-helsinki   (95.216.141.48)    — 18 Nordic/Baltic/Eastern EU identities"
echo "  box-linode-amsterdam   (172.235.174.211)  — 100 BeNeLux identities (IPv6 bound)"
echo "  box-linode-frankfurt   (172.104.143.73)   — Realm server (macula.io)"
echo ""
echo "DNS cleanup:"
echo "  Deleted: relayNN A records, all relay-* A records (shared IPv4)"
echo "  Kept: 100 relay-* AAAA records (per-identity IPv6, Amsterdam)"
echo "  Created: box-* A + AAAA records for all 4 boxes"
echo ""
echo "Total relay identities: 148 across 3 boxes"
echo "  BeNeLux (100): BE:40, NL:48, LU:12"
echo "  Central EU (30): DE, FR, UK, IE, ES, PT, IT, CH, AT, CZ, HU, SK, SI, HR, GR, RO, BG, RS"
echo "  Nordic/Eastern (18): FI, SE, NO, DK, EE, LV, LT, PL, IS"
