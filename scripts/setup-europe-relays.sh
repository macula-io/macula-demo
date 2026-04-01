#!/bin/bash
# Create DNS A records + deploy multi-tenant relay identities for 50 European cities.
#
# Distributes cities across 3 physical boxes by geographic proximity:
#   Hetzner Nuremberg (91.98.238.177) — Central/Eastern Europe
#   Hetzner Helsinki  (95.216.141.48) — Nordic/Baltic
#   Linode Frankfurt  (172.104.143.73) — West/South Europe
#
# Usage:
#   LINODE_DNS_API_TOKEN=... ./scripts/setup-europe-relays.sh

set -eu

DOMAIN_ID=1303878
TOKEN="${LINODE_DNS_API_TOKEN:?Set LINODE_DNS_API_TOKEN}"

IP_NUREMBERG="91.98.238.177"
IP_HELSINKI="95.216.141.48"
IP_FRANKFURT="172.104.143.73"

# ── City definitions: name:city:country:lat:lng:box_ip ─────────────
# Distributed by proximity to physical server location.

CITIES=(
    # ── Hetzner Nuremberg — Central/Eastern Europe (17 cities) ──
    "relay-de-nuremberg:Nuremberg:DE:49.4527:11.0783:${IP_NUREMBERG}"
    "relay-de-berlin:Berlin:DE:52.5200:13.4050:${IP_NUREMBERG}"
    "relay-de-munich:Munich:DE:48.1351:11.5820:${IP_NUREMBERG}"
    "relay-de-frankfurt:Frankfurt:DE:50.1109:8.6821:${IP_NUREMBERG}"
    "relay-de-hamburg:Hamburg:DE:53.5511:9.9937:${IP_NUREMBERG}"
    "relay-nl-amsterdam:Amsterdam:NL:52.3676:4.9041:${IP_NUREMBERG}"
    "relay-be-brussels:Brussels:BE:50.8503:4.3517:${IP_NUREMBERG}"
    "relay-be-antwerp:Antwerp:BE:51.2194:4.4025:${IP_NUREMBERG}"
    "relay-ch-zurich:Zurich:CH:47.3769:8.5417:${IP_NUREMBERG}"
    "relay-ch-geneva:Geneva:CH:46.2044:6.1432:${IP_NUREMBERG}"
    "relay-at-vienna:Vienna:AT:48.2082:16.3738:${IP_NUREMBERG}"
    "relay-cz-prague:Prague:CZ:50.0755:14.4378:${IP_NUREMBERG}"
    "relay-hu-budapest:Budapest:HU:47.4979:19.0402:${IP_NUREMBERG}"
    "relay-pl-krakow:Krakow:PL:50.0647:19.9450:${IP_NUREMBERG}"
    "relay-sk-bratislava:Bratislava:SK:48.1486:17.1077:${IP_NUREMBERG}"
    "relay-si-ljubljana:Ljubljana:SI:46.0569:14.5058:${IP_NUREMBERG}"
    "relay-lu-luxembourg:Luxembourg:LU:49.6117:6.1300:${IP_NUREMBERG}"

    # ── Hetzner Helsinki — Nordic/Baltic (15 cities) ──
    "relay-fi-helsinki:Helsinki:FI:60.1699:24.9384:${IP_HELSINKI}"
    "relay-se-stockholm:Stockholm:SE:59.3293:18.0686:${IP_HELSINKI}"
    "relay-se-gothenburg:Gothenburg:SE:57.7089:11.9746:${IP_HELSINKI}"
    "relay-no-oslo:Oslo:NO:59.9139:10.7522:${IP_HELSINKI}"
    "relay-no-bergen:Bergen:NO:60.3913:5.3221:${IP_HELSINKI}"
    "relay-dk-copenhagen:Copenhagen:DK:55.6761:12.5683:${IP_HELSINKI}"
    "relay-ee-tallinn:Tallinn:EE:59.4370:24.7536:${IP_HELSINKI}"
    "relay-lv-riga:Riga:LV:56.9496:24.1052:${IP_HELSINKI}"
    "relay-lt-vilnius:Vilnius:LT:54.6872:25.2797:${IP_HELSINKI}"
    "relay-pl-warsaw:Warsaw:PL:52.2297:21.0122:${IP_HELSINKI}"
    "relay-pl-gdansk:Gdansk:PL:54.3520:18.6466:${IP_HELSINKI}"
    "relay-de-cologne:Cologne:DE:50.9375:6.9603:${IP_HELSINKI}"
    "relay-nl-rotterdam:Rotterdam:NL:51.9225:4.4792:${IP_HELSINKI}"
    "relay-uk-edinburgh:Edinburgh:UK:55.9533:-3.1883:${IP_HELSINKI}"
    "relay-is-reykjavik:Reykjavik:IS:64.1466:-21.9426:${IP_HELSINKI}"

    # ── Linode Frankfurt — West/South Europe (18 cities) ──
    "relay-fr-paris:Paris:FR:48.8566:2.3522:${IP_FRANKFURT}"
    "relay-fr-lyon:Lyon:FR:45.7640:4.8357:${IP_FRANKFURT}"
    "relay-fr-marseille:Marseille:FR:43.2965:5.3698:${IP_FRANKFURT}"
    "relay-uk-london:London:UK:51.5074:-0.1278:${IP_FRANKFURT}"
    "relay-uk-manchester:Manchester:UK:53.4808:-2.2426:${IP_FRANKFURT}"
    "relay-ie-dublin:Dublin:IE:53.3498:-6.2603:${IP_FRANKFURT}"
    "relay-es-madrid:Madrid:ES:40.4168:-3.7038:${IP_FRANKFURT}"
    "relay-es-barcelona:Barcelona:ES:41.3874:2.1686:${IP_FRANKFURT}"
    "relay-es-valencia:Valencia:ES:39.4699:-0.3763:${IP_FRANKFURT}"
    "relay-pt-lisbon:Lisbon:PT:38.7223:-9.1393:${IP_FRANKFURT}"
    "relay-pt-porto:Porto:PT:41.1579:-8.6291:${IP_FRANKFURT}"
    "relay-it-rome:Rome:IT:41.9028:12.4964:${IP_FRANKFURT}"
    "relay-it-milan:Milan:IT:45.4642:9.1900:${IP_FRANKFURT}"
    "relay-it-naples:Naples:IT:40.8518:14.2681:${IP_FRANKFURT}"
    "relay-gr-athens:Athens:GR:37.9838:23.7275:${IP_FRANKFURT}"
    "relay-hr-zagreb:Zagreb:HR:45.8150:15.9819:${IP_FRANKFURT}"
    "relay-ro-bucharest:Bucharest:RO:44.4268:26.1025:${IP_FRANKFURT}"
    "relay-bg-sofia:Sofia:BG:42.6977:23.3219:${IP_FRANKFURT}"
)

echo "=== Creating DNS records for ${#CITIES[@]} European relay cities ==="
echo ""

created=0
skipped=0

for entry in "${CITIES[@]}"; do
    IFS=':' read -r name city country lat lng ip <<< "$entry"

    # Check if DNS record exists
    existing=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
        "https://api.linode.com/v4/domains/${DOMAIN_ID}/records?page_size=500" \
        | python3 -c "
import json,sys
records = json.load(sys.stdin).get('data',[])
matches = [r for r in records if r['name']=='${name}' and r['type']=='A']
print(matches[0]['target'] if matches else 'NONE')
" 2>/dev/null)

    if [ "${existing}" = "${ip}" ]; then
        skipped=$((skipped + 1))
        continue
    elif [ "${existing}" != "NONE" ]; then
        # Update existing record
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
        echo "  [update] ${name}.macula.io → ${ip}"
        created=$((created + 1))
    else
        curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
            -d "{\"type\": \"A\", \"name\": \"${name}\", \"target\": \"${ip}\", \"ttl_sec\": 300}" > /dev/null
        echo "  [create] ${name}.macula.io → ${ip}"
        created=$((created + 1))
    fi
done

echo ""
echo "Created/updated: ${created}, Skipped (already correct): ${skipped}"
echo ""

# ── Build MACULA_RELAY_IDENTITIES per box ──────────────────────────

build_identities() {
    local target_ip="$1"
    local result=""
    for entry in "${CITIES[@]}"; do
        IFS=':' read -r name city country lat lng ip <<< "$entry"
        [ "${ip}" != "${target_ip}" ] && continue
        [ -n "$result" ] && result="${result},"
        result="${result}${name}.macula.io:${city}:${country}:${lat}:${lng}"
    done
    echo "$result"
}

build_all_urls() {
    local result=""
    for entry in "${CITIES[@]}"; do
        IFS=':' read -r name city country lat lng ip <<< "$entry"
        [ -n "$result" ] && result="${result},"
        result="${result}https://${name}.macula.io:4433"
    done
    echo "$result"
}

NUREMBERG_IDS=$(build_identities "${IP_NUREMBERG}")
HELSINKI_IDS=$(build_identities "${IP_HELSINKI}")
FRANKFURT_IDS=$(build_identities "${IP_FRANKFURT}")
ALL_URLS=$(build_all_urls)

echo "=== Updating relay configurations ==="
echo ""

# ── Deploy to each box ─────────────────────────────────────────────

for box_info in \
    "relay00:root@relay00.macula.io:${NUREMBERG_IDS}" \
    "relay01:root@relay01.macula.io:${HELSINKI_IDS}" \
    "relay02:root@macula.io:${FRANKFURT_IDS}"; do

    IFS=':' read -r box_name ssh_target identities <<< "$box_info"
    # Fix: ssh_target gets mangled by IFS, reconstruct
    case "$box_name" in
        relay00) ssh_target="root@relay00.macula.io" ;;
        relay01) ssh_target="root@relay01.macula.io" ;;
        relay02) ssh_target="root@macula.io" ;;
    esac

    echo "[${box_name}] Updating identities..."
    ssh "${ssh_target}" "
        cd /root/macula-realm-compose
        # Update MACULA_RELAY_IDENTITIES
        if grep -q '^MACULA_RELAY_IDENTITIES=' .env 2>/dev/null; then
            # Use python to avoid sed issues with long strings
            python3 -c \"
import re
with open('.env','r') as f: content = f.read()
content = re.sub(r'^MACULA_RELAY_IDENTITIES=.*', 'MACULA_RELAY_IDENTITIES=${identities}', content, flags=re.MULTILINE)
with open('.env','w') as f: f.write(content)
print('  Updated MACULA_RELAY_IDENTITIES')
\"
        else
            echo 'MACULA_RELAY_IDENTITIES=${identities}' >> .env
            echo '  Added MACULA_RELAY_IDENTITIES'
        fi

        # Update MACULA_RELAYS
        python3 -c \"
import re
with open('.env','r') as f: content = f.read()
content = re.sub(r'^MACULA_RELAYS=.*', 'MACULA_RELAYS=${ALL_URLS}', content, flags=re.MULTILINE)
with open('.env','w') as f: f.write(content)
print('  Updated MACULA_RELAYS')
\"

        # Restart relay
        docker compose -f docker-compose-relay.yml up -d --force-recreate relay 2>&1 | grep -E '(Recreat|Start)' || true
    "
    echo "[${box_name}] Done"
    echo ""
done

echo "=== Deployment complete ==="
echo "  Nuremberg: $(echo "${NUREMBERG_IDS}" | tr ',' '\n' | wc -l) identities"
echo "  Helsinki:  $(echo "${HELSINKI_IDS}" | tr ',' '\n' | wc -l) identities"
echo "  Frankfurt: $(echo "${FRANKFURT_IDS}" | tr ',' '\n' | wc -l) identities"
echo "  Total:     ${#CITIES[@]} relay identities across Europe"
echo ""
echo "Relay graph will converge in ~60s."
echo "Check: https://macula.io/topology"
