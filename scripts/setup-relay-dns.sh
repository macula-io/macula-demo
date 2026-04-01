#!/bin/bash
# Create DNS A records for multi-tenant relay identities.
#
# Uses Linode API to create relay-{country}-{city}.macula.io records
# pointing to the appropriate physical box.
#
# Usage: ./scripts/setup-relay-dns.sh

set -eu

DOMAIN_ID=1303878
TOKEN="${LINODE_DNS_API_TOKEN:?Set LINODE_DNS_API_TOKEN env var}"

# Box IPs
HETZNER_NUREMBERG="91.98.238.177"
HETZNER_HELSINKI="95.216.141.48"
LINODE_FRANKFURT="172.104.143.73"

# Records to create: name → IP
declare -A RECORDS=(
    # Hetzner Nuremberg — Central Europe
    ["relay-de-nuremberg"]="${HETZNER_NUREMBERG}"
    ["relay-de-berlin"]="${HETZNER_NUREMBERG}"
    ["relay-nl-amsterdam"]="${HETZNER_NUREMBERG}"
    ["relay-be-brussels"]="${HETZNER_NUREMBERG}"
    ["relay-be-antwerp"]="${HETZNER_NUREMBERG}"
    ["relay-ch-zurich"]="${HETZNER_NUREMBERG}"
    ["relay-at-vienna"]="${HETZNER_NUREMBERG}"
    ["relay-cz-prague"]="${HETZNER_NUREMBERG}"
    ["relay-hu-budapest"]="${HETZNER_NUREMBERG}"

    # Hetzner Helsinki — Nordic/Baltic
    ["relay-fi-helsinki"]="${HETZNER_HELSINKI}"
    ["relay-se-stockholm"]="${HETZNER_HELSINKI}"
    ["relay-no-oslo"]="${HETZNER_HELSINKI}"
    ["relay-dk-copenhagen"]="${HETZNER_HELSINKI}"
    ["relay-ee-tallinn"]="${HETZNER_HELSINKI}"
    ["relay-lv-riga"]="${HETZNER_HELSINKI}"
    ["relay-lt-vilnius"]="${HETZNER_HELSINKI}"
    ["relay-pl-warsaw"]="${HETZNER_HELSINKI}"

    # Linode Frankfurt — West/South Europe
    ["relay-fr-paris"]="${LINODE_FRANKFURT}"
    ["relay-uk-london"]="${LINODE_FRANKFURT}"
    ["relay-ie-dublin"]="${LINODE_FRANKFURT}"
    ["relay-es-madrid"]="${LINODE_FRANKFURT}"
    ["relay-es-barcelona"]="${LINODE_FRANKFURT}"
    ["relay-pt-lisbon"]="${LINODE_FRANKFURT}"
    ["relay-it-rome"]="${LINODE_FRANKFURT}"
    ["relay-it-milan"]="${LINODE_FRANKFURT}"
)

echo "=== Creating DNS A records for relay identities ==="
echo ""

for name in $(echo "${!RECORDS[@]}" | tr ' ' '\n' | sort); do
    ip="${RECORDS[$name]}"

    # Check if record already exists
    existing=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
        "https://api.linode.com/v4/domains/${DOMAIN_ID}/records?page_size=500" \
        | python3 -c "
import json,sys
records = json.load(sys.stdin).get('data',[])
matches = [r for r in records if r['name']=='${name}' and r['type']=='A']
print(matches[0]['target'] if matches else 'NONE')
" 2>/dev/null)

    if [ "${existing}" = "${ip}" ]; then
        echo "  [skip] ${name}.macula.io → ${ip} (already exists)"
        continue
    elif [ "${existing}" != "NONE" ]; then
        echo "  [update] ${name}.macula.io → ${ip} (was ${existing})"
        # Find record ID and update
        record_id=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
            "https://api.linode.com/v4/domains/${DOMAIN_ID}/records?page_size=500" \
            | python3 -c "
import json,sys
records = json.load(sys.stdin).get('data',[])
matches = [r for r in records if r['name']=='${name}' and r['type']=='A']
print(matches[0]['id'] if matches else '')
" 2>/dev/null)
        curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "https://api.linode.com/v4/domains/${DOMAIN_ID}/records/${record_id}" \
            -d "{\"target\": \"${ip}\"}" > /dev/null
    else
        echo "  [create] ${name}.macula.io → ${ip}"
        curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
            -d "{\"type\": \"A\", \"name\": \"${name}\", \"target\": \"${ip}\", \"ttl_sec\": 300}" > /dev/null
    fi
done

echo ""
echo "Done. DNS propagation takes ~5 minutes (TTL 300s)."
echo ""
echo "Records per box:"
echo "  Hetzner Nuremberg (${HETZNER_NUREMBERG}): $(echo "${!RECORDS[@]}" | tr ' ' '\n' | while read n; do [ "${RECORDS[$n]}" = "${HETZNER_NUREMBERG}" ] && echo -n "x"; done | wc -c) relays"
echo "  Hetzner Helsinki  (${HETZNER_HELSINKI}): $(echo "${!RECORDS[@]}" | tr ' ' '\n' | while read n; do [ "${RECORDS[$n]}" = "${HETZNER_HELSINKI}" ] && echo -n "x"; done | wc -c) relays"
echo "  Linode Frankfurt  (${LINODE_FRANKFURT}): $(echo "${!RECORDS[@]}" | tr ' ' '\n' | while read n; do [ "${RECORDS[$n]}" = "${LINODE_FRANKFURT}" ] && echo -n "x"; done | wc -c) relays"
