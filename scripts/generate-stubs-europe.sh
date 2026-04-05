#!/bin/bash
# Generate stub configs for beam nodes, connected to Europe-wide relays.
#
# Creates 4 JSON files (one per beam node), each with ~35 stubs
# spread across the relay identities. Total: ~140 stubs.
#
# Each stub gets a European surname, a city near its relay, and coordinates
# with slight offset (stubs are "users" near the relay, not at the relay).
#
# Usage:
#   ./scripts/generate-stubs-europe.sh
#   # Outputs: daemon/stubs/stubs-beam0{0,1,2,3}.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../daemon/stubs"

# Get all relay identities
ALL_RELAYS=$(bash "${SCRIPT_DIR}/generate-europe-150.sh" all | tr ',' '\n')
RELAY_COUNT=$(echo "$ALL_RELAYS" | wc -l)

# European surnames by region
SURNAMES_WEST=(
  "Mueller" "Schmidt" "Schneider" "Fischer" "Weber" "Wagner" "Becker"
  "Martin" "Bernard" "Dubois" "Petit" "Moreau" "Laurent" "Simon"
  "Smith" "Jones" "Williams" "Brown" "Taylor" "Wilson" "Davies"
  "Jansen" "De-Vries" "Van-Dijk" "Bakker" "Visser" "De-Boer"
  "Garcia" "Martinez" "Lopez" "Gonzalez" "Rodriguez" "Fernandez"
  "Rossi" "Russo" "Ferrari" "Esposito" "Bianchi" "Romano"
  "Silva" "Santos" "Ferreira" "Costa" "Pereira" "Oliveira"
  "Gruber" "Huber" "Bauer" "Wagner" "Steiner" "Berger"
  "Murphy" "Kelly" "Sullivan" "Walsh" "OBrien" "Byrne"
  "Johansson" "Andersson" "Karlsson" "Nilsson" "Eriksson"
)

SURNAMES_EAST=(
  "Kowalski" "Nowak" "Wisniewski" "Wojcik" "Kaminski" "Lewandowski"
  "Shevchenko" "Bondarenko" "Kovalenko" "Tkachenko" "Melnyk" "Boyko"
  "Popescu" "Ionescu" "Popa" "Dumitru" "Stan" "Gheorghe"
  "Novak" "Horvat" "Krajnc" "Kovac" "Toth" "Nagy"
  "Ivanov" "Petrov" "Georgiev" "Dimitrov" "Nikolov" "Todorov"
  "Tamm" "Sepp" "Kask" "Rebane" "Saar" "Mets"
  "Berzins" "Ozols" "Kalns" "Vitols" "Liepa" "Egle"
  "Kazlauskas" "Jonaitis" "Petrauskas" "Stankevic" "Butkus"
  "Luik" "Pukk" "Koppel" "Ilves" "Tamm" "Sild"
  "Svoboda" "Dvorak" "Novotny" "Krejci" "Vesely" "Horak"
)

# Generate stubs for a given set of relays
generate_stubs() {
  local node_idx="$1"
  local count="$2"
  local start_idx="$3"

  echo "["
  local first=1
  for i in $(seq 0 $((count - 1))); do
    local relay_idx=$(( (start_idx + i) % RELAY_COUNT + 1 ))
    local relay_line=$(echo "$ALL_RELAYS" | sed -n "${relay_idx}p")

    IFS='/' read -r hostname city country lat lng <<< "$relay_line"

    # Pick surname based on region
    local lng_num=${lng%%.*}
    if [ "${lng_num}" -gt 15 ] 2>/dev/null; then
      local surnames=("${SURNAMES_EAST[@]}")
    else
      local surnames=("${SURNAMES_WEST[@]}")
    fi
    local name_idx=$(( (start_idx + i * 7 + node_idx * 13) % ${#surnames[@]} ))
    local surname="${surnames[$name_idx]}"
    local stub_name=$(echo "${surname}-${city}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    # Offset coordinates slightly (stubs are nearby, not exactly at relay)
    local offset_lat=$(echo "$lat" | awk "{printf \"%.4f\", \$1 + (${i} % 5 - 2) * 0.08}")
    local offset_lng=$(echo "$lng" | awk "{printf \"%.4f\", \$1 + (${i} % 7 - 3) * 0.06}")

    # Determine which box hosts this relay (Nuremberg=western, Helsinki=eastern)
    local box_host
    local lng_int=${lng%%.*}
    # Nuremberg hosts relays 1-75 (western), Helsinki hosts 76-150 (eastern)
    # Simple heuristic: relay_idx <= 75 → Nuremberg, else Helsinki
    if [ "$relay_idx" -le 75 ]; then
      box_host="box-hetzner-nuremberg.macula.io"
    else
      box_host="box-hetzner-helsinki.macula.io"
    fi

    [ $first -eq 1 ] && first=0 || echo ","
    cat <<JSON
  {
    "name": "${stub_name}",
    "city": "${city}",
    "country": "${country}",
    "lat": ${offset_lat},
    "lng": ${offset_lng},
    "relay": "https://${box_host}:4433"
  }
JSON
  done
  echo "]"
}

mkdir -p "${OUT_DIR}"

# 35 stubs per node = 140 total, spread across 150 relays
generate_stubs 0 35 0   > "${OUT_DIR}/stubs-beam00.json"
generate_stubs 1 35 35  > "${OUT_DIR}/stubs-beam01.json"
generate_stubs 2 35 70  > "${OUT_DIR}/stubs-beam02.json"
generate_stubs 3 35 105 > "${OUT_DIR}/stubs-beam03.json"

echo "Generated stub configs:"
for f in "${OUT_DIR}"/stubs-beam0*.json; do
  count=$(python3 -c "import json; print(len(json.load(open('$f'))))")
  echo "  $(basename $f): ${count} stubs"
done
echo "Total: $(python3 -c "
import json, glob
total = sum(len(json.load(open(f))) for f in glob.glob('${OUT_DIR}/stubs-beam0*.json'))
print(total)
") stubs across 4 nodes"
