#!/bin/bash
# Generate ~2000 stub identities (500 per beam node) across Europe.
# Mix of family households and business sites.
#
# Usage:
#   ./scripts/generate-stubs-2000.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/../daemon/stubs"

# Get all relay identities with their box assignments
NUR_RELAYS=$(bash "${SCRIPT_DIR}/generate-europe-150.sh" nuremberg | tr ',' '\n')
HEL_RELAYS=$(bash "${SCRIPT_DIR}/generate-europe-150.sh" helsinki | tr ',' '\n')

mkdir -p "${OUT_DIR}"

python3 << 'PYGEN'
import json, random, os

random.seed(42)  # reproducible

nur_relays = []
hel_relays = []

for line in open("/dev/stdin").read().strip().split("---SPLIT---"):
    pass

# Read relay lists from env
nur_lines = os.environ["NUR_RELAYS"].strip().split("\n")
hel_lines = os.environ["HEL_RELAYS"].strip().split("\n")

for line in nur_lines:
    parts = line.split("/")
    if len(parts) >= 5:
        nur_relays.append({
            "hostname": parts[0], "city": parts[1], "country": parts[2],
            "lat": float(parts[3]), "lng": float(parts[4]),
            "box": "box-hetzner-nuremberg.macula.io"
        })

for line in hel_lines:
    parts = line.split("/")
    if len(parts) >= 5:
        hel_relays.append({
            "hostname": parts[0], "city": parts[1], "country": parts[2],
            "lat": float(parts[3]), "lng": float(parts[4]),
            "box": "box-hetzner-helsinki.macula.io"
        })

all_relays = nur_relays + hel_relays

# ── Name pools ───────────────────────────────────────────────────

family_surnames = {
    "GB": ["Smith","Jones","Williams","Brown","Taylor","Wilson","Davies","Evans","Thomas","Roberts",
           "Walker","Wright","Robinson","Thompson","White","Hall","Green","Harris","Clark","Lewis"],
    "IE": ["Murphy","Kelly","Sullivan","Walsh","OBrien","Byrne","Ryan","OConnor","Doyle","McCarthy"],
    "FR": ["Martin","Bernard","Dubois","Petit","Moreau","Laurent","Simon","Michel","Leroy","Roux",
           "David","Bertrand","Morel","Fournier","Girard","Bonnet","Dupont","Lambert","Fontaine"],
    "BE": ["Peeters","Janssen","Maes","Jacobs","Willems","Claes","Goossens","Wouters","De-Smedt"],
    "NL": ["De-Jong","Jansen","De-Vries","Van-Dijk","Bakker","Visser","Smit","Meijer","Mulder"],
    "DE": ["Mueller","Schmidt","Schneider","Fischer","Weber","Wagner","Becker","Hoffmann","Koch"],
    "AT": ["Gruber","Huber","Bauer","Wagner","Steiner","Berger","Winkler","Moser","Eder","Pichler"],
    "CH": ["Mueller","Meier","Schmid","Keller","Weber","Huber","Schneider","Meyer","Steiner"],
    "ES": ["Garcia","Martinez","Lopez","Gonzalez","Rodriguez","Fernandez","Sanchez","Perez","Gomez"],
    "PT": ["Silva","Santos","Ferreira","Costa","Pereira","Oliveira","Martins","Rodrigues","Alves"],
    "IT": ["Rossi","Russo","Ferrari","Esposito","Bianchi","Romano","Colombo","Ricci","Marino","Greco"],
    "SE": ["Johansson","Andersson","Karlsson","Nilsson","Eriksson","Larsson","Olsson","Persson"],
    "NO": ["Hansen","Johansen","Olsen","Larsen","Andersen","Pedersen","Nilsen","Kristiansen"],
    "DK": ["Jensen","Nielsen","Hansen","Pedersen","Andersen","Christensen","Larsen","Sorensen"],
    "FI": ["Korhonen","Virtanen","Makinen","Nieminen","Makela","Hamalainen","Laine","Heikkinen"],
    "PL": ["Nowak","Kowalski","Wisniewski","Wojcik","Kaminski","Lewandowski","Zielinski","Wozniak"],
    "CZ": ["Novak","Svoboda","Novotny","Dvorak","Cerny","Prochazka","Kucera","Vesely","Horak"],
    "SK": ["Horvath","Kovac","Varga","Toth","Nagy","Balan","Molnar","Szabo"],
    "HU": ["Nagy","Kovacs","Toth","Szabo","Horvath","Varga","Kiss","Molnar","Nemeth","Farkas"],
    "RO": ["Popescu","Ionescu","Popa","Stan","Dumitru","Gheorghe","Stoica","Ciobanu","Marin"],
    "BG": ["Ivanov","Petrov","Georgiev","Dimitrov","Nikolov","Todorov","Stoyanov","Angelov"],
    "GR": ["Papadopoulos","Vlachos","Papadimitriou","Karagiannis","Nikolaou","Georgiou"],
    "UA": ["Shevchenko","Bondarenko","Kovalenko","Tkachenko","Melnyk","Boyko","Moroz","Lysenko",
           "Savchenko","Marchenko","Rudenko","Petrenko","Kravchenko","Oliynyk","Polishchuk",
           "Shevchuk","Yarosh","Gavrylyuk","Tymoshenko","Ponomarenko","Zinchenko","Mazur"],
    "LT": ["Kazlauskas","Jonaitis","Petrauskas","Stankevic","Butkus","Paulauskas"],
    "LV": ["Berzins","Ozols","Kalns","Vitols","Liepa","Egle","Krumins","Vanags"],
    "EE": ["Tamm","Sepp","Kask","Rebane","Saar","Mets","Luik","Pukk","Koppel","Ilves"],
    "MD": ["Moldovan","Cojocaru","Rusu","Ceban","Lungu","Moraru"],
    "HR": ["Horvat","Kovacevic","Babic","Maric","Juric","Novak"],
    "RS": ["Jovanovic","Petrovic","Nikolic","Djordjevic","Markovic"],
    "SI": ["Novak","Horvat","Krajnc","Kovacic","Potocnik"],
    "BA": ["Hadzic","Kovacevic","Begovic","Djuric"],
    "ME": ["Popovic","Vujovic","Radulovic"],
    "AL": ["Hoxha","Shehu","Krasniqi"],
    "MK": ["Stojanovski","Trajkovski","Petrov"],
    "IS": ["Sigurdsson","Jonsson","Gudmundsson"],
    "MT": ["Borg","Camilleri","Vella"],
    "CY": ["Georgiou","Christodoulou","Ioannou"],
    "LU": ["Weber","Schmit","Muller","Hoffmann"],
}

business_types = [
    "bakery", "cafe", "pharmacy", "clinic", "school", "gym", "hotel",
    "garage", "florist", "dentist", "vet", "studio", "salon", "lab",
    "farm", "brewery", "winery", "creamery", "workshop", "forge",
    "tech", "digital", "cloud", "data", "cyber", "web", "app",
    "solar", "wind", "bio", "eco", "green", "smart",
    "logistics", "transport", "express", "freight",
    "media", "press", "radio", "print",
    "legal", "consult", "audit", "tax",
    "design", "arch", "build", "construct",
    "food", "fresh", "organic", "market",
]

business_suffixes = [
    "hub", "works", "point", "center", "house", "place", "base",
    "pro", "plus", "co", "group", "team", "lab", "zone",
]

def get_surnames(country):
    return family_surnames.get(country, family_surnames.get("DE"))

def make_family_name(country, idx):
    surnames = get_surnames(country)
    surname = surnames[idx % len(surnames)]
    # Families: "the-smiths", "van-dijk-family", "casa-garcia"
    prefixes = {
        "NL": "van", "BE": "de", "FR": "famille", "ES": "casa",
        "IT": "casa", "PT": "casa", "DE": "familie",
    }
    prefix = prefixes.get(country, "the")
    return f"{prefix}-{surname}".lower()

def make_business_name(country, city, idx):
    btype = business_types[idx % len(business_types)]
    suffix = business_suffixes[(idx * 7) % len(business_suffixes)]
    city_short = city.lower().replace(" ", "-")[:8]
    return f"{city_short}-{btype}-{suffix}"

def generate_stubs(node_idx, count, relay_list, all_relays_list):
    stubs = []
    for i in range(count):
        relay = relay_list[i % len(relay_list)]

        # 60% family, 40% business
        is_family = (i * 3 + node_idx) % 5 < 3

        if is_family:
            name = make_family_name(relay["country"], i + node_idx * 500)
            site_type = "family"
        else:
            name = make_business_name(relay["country"], relay["city"], i + node_idx * 500)
            site_type = "business"

        # Ensure unique name
        name = f"{name}-{i}"

        # Offset from relay (stubs are nearby users)
        lat_offset = ((i * 17 + node_idx * 31) % 100 - 50) * 0.005
        lng_offset = ((i * 23 + node_idx * 37) % 100 - 50) * 0.004

        stubs.append({
            "name": name,
            "city": relay["city"],
            "country": relay["country"],
            "lat": round(relay["lat"] + lat_offset, 4),
            "lng": round(relay["lng"] + lng_offset, 4),
            "relay": f"https://{relay['box']}:4433",
            "site_type": site_type,
        })

    return stubs

# Split relays for each node: round-robin across all relays
nodes = [
    generate_stubs(0, 500, all_relays, all_relays),
    generate_stubs(1, 500, all_relays, all_relays),
    generate_stubs(2, 500, all_relays, all_relays),
    generate_stubs(3, 500, all_relays, all_relays),
]

out_dir = os.environ.get("OUT_DIR", "daemon/stubs")
for i, stubs in enumerate(nodes):
    path = f"{out_dir}/stubs-beam0{i}.json"
    with open(path, "w") as f:
        json.dump(stubs, f, indent=2)

    # Count by relay box
    boxes = {}
    types = {"family": 0, "business": 0}
    countries = {}
    for s in stubs:
        box = s["relay"].split("//")[1].split(":")[0]
        boxes[box] = boxes.get(box, 0) + 1
        types[s["site_type"]] = types.get(s["site_type"], 0) + 1
        countries[s["country"]] = countries.get(s["country"], 0) + 1

    print(f"beam0{i}: {len(stubs)} stubs ({types['family']} family, {types['business']} business)")
    for box, cnt in sorted(boxes.items()):
        print(f"  {box}: {cnt}")

print(f"\nTotal: {sum(len(n) for n in nodes)} stubs")
PYGEN
