#!/usr/bin/env python3
"""Generate BeNeLux household/business stub identities as JSON config files.

Creates 4 files (800 total):
  - stubs-beam00.json (100 identities)
  - stubs-beam01.json (200 identities)
  - stubs-beam02.json (250 identities)
  - stubs-beam03.json (250 identities)

Each identity has: name, city, country, lat/lng (15km jitter), relay, site.
"""

import json
import random
import os
import math
import hashlib

random.seed(42)

# ── Names ────────────────────────────────────────────────────────

FAMILIES = [
    "janssens", "peeters", "maes", "jacobs", "willems", "mertens", "claes",
    "goossens", "wouters", "de-smedt", "hermans", "lambert", "dubois",
    "martin", "simon", "laurent", "lejeune", "renard", "leclercq", "thomas",
    "vandenberghe", "de-graef", "stevens", "michiels", "cools", "bogaert",
    "desmet", "hendrickx", "de-cock", "pauwels", "vermeersch", "baert",
    "lammens", "nijs", "smeets", "thijs", "aerts", "van-damme", "vos",
    "de-wolf", "pieters", "devos", "leemans", "martens", "brouwers",
    "vandenbulcke", "sels", "van-acker", "vanhees", "wuyts",
    "de-bruyne", "claessens", "govaerts", "somers", "verhoeven",
    "van-hoeck", "lenaerts", "buelens", "dams", "beckers",
    "heylen", "van-dyck", "bernaerts", "verbeke", "de-meyer",
    "vaes", "geerts", "wauters", "lemaire", "dumont", "pirard",
    "gilles", "leonard", "marchal", "delcourt", "renson", "cornet",
    "bodart", "collignon", "adam", "georges", "henrotte", "servais",
    # Dutch names
    "de-vries", "van-den-berg", "bakker", "visser", "smit", "de-boer",
    "mulder", "de-groot", "bos", "vos-nl", "peters", "hendriks",
    "van-dijk", "de-jong", "jansen", "van-leeuwen", "dekker", "brouwer",
    "de-wit", "dijkstra", "kok", "van-der-linden", "huisman", "kuijpers",
    "schouten", "van-der-heijden", "hoekstra", "van-der-wal",
    # Luxembourgish names
    "weber", "schmit", "muller-lu", "hoffmann", "wagner", "klein",
    "meyer", "schneider", "becker-lu", "schiltz",
]

BUSINESSES = [
    "bakkerij-artisan", "cafe-de-markt", "tech-flanders", "studio-creatief",
    "garage-vdb", "apotheek-centraal", "frituur-de-hoek", "advocaat-stevens",
    "architect-bogaert", "slagerij-peeters", "bloemen-maes", "drukkerij-claes",
    "fietsen-willems", "boekhandel-hermans", "taverne-de-leeuw",
    "kapsalon-elegance", "immo-trust", "webdesign-pixel", "elektro-jacobs",
    "brasserie-leopold", "patisserie-duchene", "librairie-mols",
    "boucherie-dubois", "garage-martin", "pharmacie-lambert",
    "cabinet-lejeune", "epicerie-fine", "traiteur-renard",
    "menuiserie-leclercq", "plomberie-thomas", "atelier-simon",
    "fromagerie-laurent", "chocolaterie-artisan", "brasserie-oud-brugge",
    "vinothek-somelier", "cybercafe-connect", "dataworks-bv",
    "cloudnine-tech", "meshworks-bvba", "edgecompute-be",
    "iot-solutions-gent", "smart-grid-antwerp", "neural-labs-leuven",
    "quantum-bru", "biotech-liege", "greenpower-namur",
    "logistiek-zeebrugge", "maritiem-antwerpen", "diamant-exchange",
    "chocolade-praline", "wafel-paradijs",
    # Dutch businesses
    "kaashandel-gouda", "fietswinkel-utrecht", "brouwerij-amsterdam",
    "techpark-eindhoven", "havenlogistiek-rotterdam", "bloemenveiling-aalsmeer",
    "designstudio-delft", "agritech-wageningen", "solar-almere",
    "windpark-groningen", "data-center-amsterdam", "fintech-zuidas",
    # Luxembourg businesses
    "banque-luxembourg", "eurostat-services", "steel-esch",
]

# ── BeNeLux cities with weights ──────────────────────────────────

CITIES = []

# Belgium (106 cities from generate-benelux-relays.py)
_BE = [
    ("Brussels", 50.8503, 4.3517, 20), ("Antwerp", 51.2194, 4.4025, 15),
    ("Ghent", 51.0543, 3.7174, 12), ("Bruges", 51.2093, 3.2247, 6),
    ("Liege", 50.6292, 5.5797, 10), ("Leuven", 50.8798, 4.7005, 8),
    ("Namur", 50.4674, 4.8720, 6), ("Charleroi", 50.4108, 4.4446, 7),
    ("Mechelen", 51.0259, 4.4776, 5), ("Hasselt", 50.9307, 5.3375, 5),
    ("Kortrijk", 50.8279, 3.2649, 4), ("Ostend", 51.2254, 2.9199, 4),
    ("Mons", 50.4542, 3.9566, 4), ("Aalst", 50.9383, 4.0393, 4),
    ("Tournai", 50.6058, 3.3881, 3), ("Arlon", 49.6834, 5.8166, 2),
    ("Sint-Niklaas", 51.1564, 4.1573, 3), ("Roeselare", 50.9469, 3.1244, 3),
    ("Verviers", 50.5883, 5.8631, 3), ("Genk", 50.9650, 5.5025, 3),
    ("Turnhout", 51.3225, 4.9484, 3), ("La Louviere", 50.4712, 4.1858, 2),
    ("Wavre", 50.7157, 4.6113, 3), ("Mouscron", 50.7426, 3.2190, 2),
    ("Dendermonde", 51.0284, 4.1004, 2), ("Seraing", 50.5833, 5.5000, 2),
    ("Lier", 51.1311, 4.5700, 2), ("Diest", 50.9893, 5.0509, 1),
    ("Tongeren", 50.7805, 5.4646, 1), ("Waregem", 50.8789, 3.4244, 1),
    ("Ypres", 50.8519, 2.8858, 2), ("Tienen", 50.8072, 4.9368, 1),
    ("Herentals", 51.1765, 4.8343, 1), ("Mol", 51.1897, 5.1147, 1),
    ("Halle", 50.7336, 4.2345, 2), ("Vilvoorde", 50.9278, 4.4248, 2),
    ("Lokeren", 51.1043, 3.9890, 1), ("Beveren", 51.2108, 4.2572, 1),
    ("Sint-Truiden", 50.8167, 5.1833, 1), ("Bilzen", 50.8728, 5.5178, 1),
    ("Lommel", 51.2307, 5.3144, 1), ("Geel", 51.1618, 4.9898, 1),
]
for city, lat, lng, w in _BE:
    slug = city.lower().replace(" ", "-").replace("'", "")
    CITIES.append((city, "BE", lat, lng, f"relay-be-{slug}", w))

# Netherlands (top 40 by weight)
_NL = [
    ("Amsterdam", 52.3676, 4.9041, 12), ("Rotterdam", 51.9244, 4.4777, 10),
    ("The Hague", 52.0705, 4.3007, 8), ("Utrecht", 52.0907, 5.1214, 7),
    ("Eindhoven", 51.4416, 5.4697, 6), ("Tilburg", 51.5555, 5.0913, 4),
    ("Groningen", 53.2194, 6.5665, 4), ("Breda", 51.5719, 4.7683, 4),
    ("Nijmegen", 51.8126, 5.8372, 4), ("Arnhem", 51.9851, 5.8987, 3),
    ("Haarlem", 52.3874, 4.6462, 3), ("Enschede", 52.2215, 6.8937, 3),
    ("Amersfoort", 52.1561, 5.3878, 3), ("Den Bosch", 51.6978, 5.3037, 3),
    ("Leiden", 52.1601, 4.4970, 3), ("Dordrecht", 51.8133, 4.6901, 2),
    ("Delft", 52.0116, 4.3571, 2), ("Leeuwarden", 53.2012, 5.7999, 2),
    ("Maastricht", 50.8514, 5.6910, 3), ("Venlo", 51.3704, 6.1724, 2),
    ("Heerlen", 50.8882, 5.9793, 2), ("Gouda", 52.0115, 4.7105, 2),
    ("Zwolle", 52.5168, 6.0830, 2), ("Hilversum", 52.2292, 5.1765, 2),
    ("Middelburg", 51.4988, 3.6136, 1), ("Bergen-op-Zoom", 51.4950, 4.2889, 1),
    ("Deventer", 52.2510, 6.1598, 1), ("Apeldoorn", 52.2112, 5.9699, 2),
    ("Almere", 52.3508, 5.2647, 2), ("Zoetermeer", 52.0575, 4.4931, 1),
]
for city, lat, lng, w in _NL:
    slug = city.lower().replace(" ", "-").replace("'", "")
    CITIES.append((city, "NL", lat, lng, f"relay-nl-{slug}", w))

# Luxembourg
_LU = [
    ("Luxembourg", 49.6117, 6.1319, 4), ("Esch-sur-Alzette", 49.4958, 5.9806, 2),
    ("Differdange", 49.5242, 5.8914, 1), ("Ettelbruck", 49.8472, 6.1042, 1),
]
for city, lat, lng, w in _LU:
    slug = city.lower().replace(" ", "-").replace("'", "")
    CITIES.append((city, "LU", lat, lng, f"relay-lu-{slug}", w))


def jitter(lat, lng, radius_km=12.0):
    """Add random offset within radius_km using polar coordinates."""
    angle = random.uniform(0, 2 * math.pi)
    dist = radius_km * math.sqrt(random.random())
    dlat = dist * math.cos(angle) / 111.0
    dlng = dist * math.sin(angle) / (111.0 * math.cos(math.radians(lat)))
    return round(lat + dlat, 5), round(lng + dlng, 5)


def generate_identities(count, name_pool, start_idx=0):
    identities = []
    names_used = set()

    weighted_cities = []
    for city, cc, lat, lng, relay, weight in CITIES:
        weighted_cities.extend([(city, cc, lat, lng, relay)] * weight)

    for i in range(count):
        idx = (start_idx + i) % len(name_pool)
        base_name = name_pool[idx]

        name = base_name
        suffix = 2
        while name in names_used:
            name = f"{base_name}-{suffix}"
            suffix += 1
        names_used.add(name)

        city, cc, clat, clng, relay = random.choice(weighted_cities)
        lat, lng = jitter(clat, clng, radius_km=12.0)

        site_id = hashlib.sha256(f"site-{name}".encode()).hexdigest()[:16]
        is_business = name in BUSINESSES
        site_type = "business" if is_business else "household"

        identities.append({
            "name": name,
            "city": city,
            "country": cc,
            "lat": lat,
            "lng": lng,
            "relay": f"https://{relay}.macula.io:4433",
            "site": {
                "site_id": site_id,
                "name": name.replace("-", " ").title(),
                "city": city,
                "country": cc,
                "lat": lat,
                "lng": lng,
                "site_type": site_type
            }
        })

    return identities


all_names = FAMILIES + BUSINESSES
random.shuffle(all_names)

out_dir = os.path.join(os.path.dirname(__file__), "..", "daemon", "stubs")

# beam00: 100, beam01: 200, beam02: 250, beam03: 250 = 800 total
configs = [
    ("beam00", 100, 0),
    ("beam01", 200, 100),
    ("beam02", 250, 300),
    ("beam03", 250, 550),
]

for node, count, offset in configs:
    ids = generate_identities(count, all_names, offset)
    with open(os.path.join(out_dir, f"stubs-{node}.json"), "w") as f:
        json.dump(ids, f, indent=2)
    print(f"{node}: {count} identities")

# Summary
all_ids = []
for node, count, offset in configs:
    with open(os.path.join(out_dir, f"stubs-{node}.json")) as f:
        all_ids.extend(json.load(f))

countries = {}
cities = {}
for i in all_ids:
    countries[i["country"]] = countries.get(i["country"], 0) + 1
    cities[i["city"]] = cities.get(i["city"], 0) + 1

print(f"\nTotal: {len(all_ids)} identities")
for cc in sorted(countries): print(f"  {cc}: {countries[cc]}")
print(f"Across {len(cities)} cities")
for c in sorted(cities, key=lambda x: -cities[x])[:10]:
    print(f"  {c}: {cities[c]}")
