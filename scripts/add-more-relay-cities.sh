#!/bin/bash
# Add 50 more European relay cities to the existing 50.
# Uses same physical boxes, same ports, just more virtual identities.

set -eu

DOMAIN_ID=1303878
TOKEN="${LINODE_DNS_API_TOKEN:?Set LINODE_DNS_API_TOKEN}"

IP_NUREMBERG="91.98.238.177"
IP_HELSINKI="95.216.141.48"
IP_FRANKFURT="172.104.143.73"

# New cities to add (on top of existing 50)
CITIES=(
    # ── Hetzner Nuremberg — more Central/Eastern Europe ──
    "relay-de-bremen:Bremen:DE:53.0793:8.8017:${IP_NUREMBERG}"
    "relay-de-essen:Essen:DE:51.4556:7.0116:${IP_NUREMBERG}"
    "relay-de-leipzig:Leipzig:DE:51.3397:12.3731:${IP_NUREMBERG}"
    "relay-de-dresden:Dresden:DE:51.0504:13.7373:${IP_NUREMBERG}"
    "relay-de-hannover:Hannover:DE:52.3759:9.7320:${IP_NUREMBERG}"
    "relay-de-dortmund:Dortmund:DE:51.5136:7.4653:${IP_NUREMBERG}"
    "relay-de-dusseldorf:Dusseldorf:DE:51.2277:6.7735:${IP_NUREMBERG}"
    "relay-nl-utrecht:Utrecht:NL:52.0907:5.1214:${IP_NUREMBERG}"
    "relay-nl-eindhoven:Eindhoven:NL:51.4416:5.4697:${IP_NUREMBERG}"
    "relay-be-liege:Liege:BE:50.6292:5.5797:${IP_NUREMBERG}"
    "relay-ch-basel:Basel:CH:47.5596:7.5886:${IP_NUREMBERG}"
    "relay-ch-bern:Bern:CH:46.9480:7.4474:${IP_NUREMBERG}"
    "relay-at-graz:Graz:AT:47.0707:15.4395:${IP_NUREMBERG}"
    "relay-at-salzburg:Salzburg:AT:47.8095:13.0550:${IP_NUREMBERG}"
    "relay-cz-brno:Brno:CZ:49.1951:16.6068:${IP_NUREMBERG}"
    "relay-pl-wroclaw:Wroclaw:PL:51.1079:17.0385:${IP_NUREMBERG}"
    "relay-pl-poznan:Poznan:PL:52.4064:16.9252:${IP_NUREMBERG}"

    # ── Hetzner Helsinki — more Nordic/Baltic/Eastern ──
    "relay-se-malmo:Malmo:SE:55.6050:13.0038:${IP_HELSINKI}"
    "relay-se-uppsala:Uppsala:SE:59.8586:17.6389:${IP_HELSINKI}"
    "relay-dk-aarhus:Aarhus:DK:56.1629:10.2039:${IP_HELSINKI}"
    "relay-fi-tampere:Tampere:FI:61.4978:23.7610:${IP_HELSINKI}"
    "relay-fi-oulu:Oulu:FI:65.0121:25.4651:${IP_HELSINKI}"
    "relay-lt-kaunas:Kaunas:LT:54.8985:23.9036:${IP_HELSINKI}"
    "relay-pl-lodz:Lodz:PL:51.7592:19.4560:${IP_HELSINKI}"
    "relay-pl-szczecin:Szczecin:PL:53.4285:14.5528:${IP_HELSINKI}"
    "relay-hu-debrecen:Debrecen:HU:47.5316:21.6273:${IP_HELSINKI}"
    "relay-ro-cluj:Cluj:RO:46.7712:23.6236:${IP_HELSINKI}"
    "relay-ro-timisoara:Timisoara:RO:45.7489:21.2087:${IP_HELSINKI}"
    "relay-ua-kyiv:Kyiv:UA:50.4501:30.5234:${IP_HELSINKI}"
    "relay-ua-lviv:Lviv:UA:49.8397:24.0297:${IP_HELSINKI}"
    "relay-md-chisinau:Chisinau:MD:47.0105:28.8638:${IP_HELSINKI}"
    "relay-by-minsk:Minsk:BY:53.9006:27.5590:${IP_HELSINKI}"

    # ── Linode Frankfurt — more West/South/Southeast ──
    "relay-uk-birmingham:Birmingham:UK:52.4862:-1.8904:${IP_FRANKFURT}"
    "relay-uk-glasgow:Glasgow:UK:55.8642:-4.2518:${IP_FRANKFURT}"
    "relay-uk-bristol:Bristol:UK:51.4545:-2.5879:${IP_FRANKFURT}"
    "relay-fr-lille:Lille:FR:50.6292:3.0573:${IP_FRANKFURT}"
    "relay-fr-nantes:Nantes:FR:47.2184:-1.5536:${IP_FRANKFURT}"
    "relay-fr-bordeaux:Bordeaux:FR:44.8378:-0.5792:${IP_FRANKFURT}"
    "relay-es-seville:Seville:ES:37.3891:-5.9845:${IP_FRANKFURT}"
    "relay-es-bilbao:Bilbao:ES:43.2630:-2.9350:${IP_FRANKFURT}"
    "relay-es-malaga:Malaga:ES:36.7213:-4.4214:${IP_FRANKFURT}"
    "relay-it-bologna:Bologna:IT:44.4949:11.3426:${IP_FRANKFURT}"
    "relay-it-florence:Florence:IT:43.7696:11.2558:${IP_FRANKFURT}"
    "relay-it-palermo:Palermo:IT:38.1157:13.3615:${IP_FRANKFURT}"
    "relay-it-genoa:Genoa:IT:44.4056:8.9463:${IP_FRANKFURT}"
    "relay-rs-belgrade:Belgrade:RS:44.7866:20.4489:${IP_FRANKFURT}"
    "relay-al-tirana:Tirana:AL:41.3275:19.8187:${IP_FRANKFURT}"
    "relay-tr-istanbul:Istanbul:TR:41.0082:28.9784:${IP_FRANKFURT}"
    "relay-cy-nicosia:Nicosia:CY:35.1856:33.3823:${IP_FRANKFURT}"
    "relay-mt-valletta:Valletta:MT:35.8989:14.5146:${IP_FRANKFURT}"
)

echo "=== Adding ${#CITIES[@]} more relay cities ==="

created=0
skipped=0
for entry in "${CITIES[@]}"; do
    IFS=':' read -r name city country lat lng ip <<< "$entry"
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
    elif [ "${existing}" != "NONE" ]; then
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
        echo "  [update] ${name}.macula.io"
        created=$((created + 1))
    else
        curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "https://api.linode.com/v4/domains/${DOMAIN_ID}/records" \
            -d "{\"type\": \"A\", \"name\": \"${name}\", \"target\": \"${ip}\", \"ttl_sec\": 300}" > /dev/null
        echo "  [create] ${name}.macula.io"
        created=$((created + 1))
    fi
done

echo ""
echo "Created: ${created}, Skipped: ${skipped}"

# ── Build updated MACULA_RELAY_IDENTITIES per box ──
echo ""
echo "=== Identity strings for each box ==="

# Combine original + new cities
ALL_CITIES_FILE=$(mktemp)
cat > "${ALL_CITIES_FILE}" << 'ORIGINAL_CITIES'
relay-de-nuremberg:Nuremberg:DE:49.4527:11.0783
relay-de-berlin:Berlin:DE:52.5200:13.4050
relay-de-munich:Munich:DE:48.1351:11.5820
relay-de-frankfurt:Frankfurt:DE:50.1109:8.6821
relay-de-hamburg:Hamburg:DE:53.5511:9.9937
relay-nl-amsterdam:Amsterdam:NL:52.3676:4.9041
relay-be-brussels:Brussels:BE:50.8503:4.3517
relay-be-antwerp:Antwerp:BE:51.2194:4.4025
relay-ch-zurich:Zurich:CH:47.3769:8.5417
relay-ch-geneva:Geneva:CH:46.2044:6.1432
relay-at-vienna:Vienna:AT:48.2082:16.3738
relay-cz-prague:Prague:CZ:50.0755:14.4378
relay-hu-budapest:Budapest:HU:47.4979:19.0402
relay-pl-krakow:Krakow:PL:50.0647:19.9450
relay-sk-bratislava:Bratislava:SK:48.1486:17.1077
relay-si-ljubljana:Ljubljana:SI:46.0569:14.5058
relay-lu-luxembourg:Luxembourg:LU:49.6117:6.1300
relay-fi-helsinki:Helsinki:FI:60.1699:24.9384
relay-se-stockholm:Stockholm:SE:59.3293:18.0686
relay-se-gothenburg:Gothenburg:SE:57.7089:11.9746
relay-no-oslo:Oslo:NO:59.9139:10.7522
relay-no-bergen:Bergen:NO:60.3913:5.3221
relay-dk-copenhagen:Copenhagen:DK:55.6761:12.5683
relay-ee-tallinn:Tallinn:EE:59.4370:24.7536
relay-lv-riga:Riga:LV:56.9496:24.1052
relay-lt-vilnius:Vilnius:LT:54.6872:25.2797
relay-pl-warsaw:Warsaw:PL:52.2297:21.0122
relay-pl-gdansk:Gdansk:PL:54.3520:18.6466
relay-de-cologne:Cologne:DE:50.9375:6.9603
relay-nl-rotterdam:Rotterdam:NL:51.9225:4.4792
relay-uk-edinburgh:Edinburgh:UK:55.9533:-3.1883
relay-is-reykjavik:Reykjavik:IS:64.1466:-21.9426
relay-fr-paris:Paris:FR:48.8566:2.3522
relay-fr-lyon:Lyon:FR:45.7640:4.8357
relay-fr-marseille:Marseille:FR:43.2965:5.3698
relay-uk-london:London:UK:51.5074:-0.1278
relay-uk-manchester:Manchester:UK:53.4808:-2.2426
relay-ie-dublin:Dublin:IE:53.3498:-6.2603
relay-es-madrid:Madrid:ES:40.4168:-3.7038
relay-es-barcelona:Barcelona:ES:41.3874:2.1686
relay-es-valencia:Valencia:ES:39.4699:-0.3763
relay-pt-lisbon:Lisbon:PT:38.7223:-9.1393
relay-pt-porto:Porto:PT:41.1579:-8.6291
relay-it-rome:Rome:IT:41.9028:12.4964
relay-it-milan:Milan:IT:45.4642:9.1900
relay-it-naples:Naples:IT:40.8518:14.2681
relay-gr-athens:Athens:GR:37.9838:23.7275
relay-hr-zagreb:Zagreb:HR:45.8150:15.9819
relay-ro-bucharest:Bucharest:RO:44.4268:26.1025
relay-bg-sofia:Sofia:BG:42.6977:23.3219
ORIGINAL_CITIES

for entry in "${CITIES[@]}"; do
    IFS=':' read -r name city country lat lng ip <<< "$entry"
    echo "${name}:${city}:${country}:${lat}:${lng}" >> "${ALL_CITIES_FILE}"
done

echo "Nuremberg identities:"
grep -E "^relay-(de-|nl-|be-|ch-|at-|cz-|hu-|pl-(krakow|wroclaw|poznan)|sk-|si-|lu-)" "${ALL_CITIES_FILE}" | wc -l

echo "Helsinki identities:"
grep -E "^relay-(fi-|se-|no-|dk-|ee-|lv-|lt-|pl-(warsaw|gdansk|lodz|szczecin)|is-|ro-(cluj|timisoara)|hu-debrecen|ua-|md-|by-|de-cologne|nl-rotterdam|uk-edinburgh)" "${ALL_CITIES_FILE}" | wc -l

echo "Frankfurt identities:"
grep -E "^relay-(fr-|uk-(london|manchester|birmingham|glasgow|bristol)|ie-|es-|pt-|it-|gr-|hr-|bg-|ro-bucharest|rs-|al-|tr-|cy-|mt-)" "${ALL_CITIES_FILE}" | wc -l

rm "${ALL_CITIES_FILE}"

echo ""
echo "Done. Now update MACULA_RELAY_IDENTITIES on each box."
echo "Run: ./scripts/setup-europe-relays.sh (updated with new cities)"
