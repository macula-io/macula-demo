#!/usr/bin/env python3
"""Generate Belgian household/business stub identities as JSON config files.

Creates 4 files:
  - stubs-beam00.json (50 identities)
  - stubs-beam01.json (100 identities)
  - stubs-beam02.json (100 identities)
  - stubs-beam03.json (100 identities)

Each identity has:
  - name: MRI-style (janssens, bakkerij-vdb, etc.)
  - city: Belgian municipality
  - country: BE
  - lat/lng: street-level coordinates (jittered from city center)
  - relay: nearest relay URL
"""

import json
import random
import os
import math

random.seed(42)  # Deterministic for reproducibility

# Belgian family names (top 50)
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
]

# Belgian business names
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
]

# Belgian cities with coordinates and relay
CITIES = [
    # Major cities (more density)
    ("Brussels", 50.8503, 4.3517, "relay-be-brussels", 15),
    ("Antwerp", 51.2194, 4.4025, "relay-be-antwerp", 12),
    ("Ghent", 51.0543, 3.7174, "relay-be-ghent", 10),
    ("Bruges", 51.2093, 3.2247, "relay-be-bruges", 5),
    ("Liege", 50.6292, 5.5797, "relay-be-liege", 8),
    ("Leuven", 50.8798, 4.7005, "relay-be-leuven", 6),
    ("Namur", 50.4674, 4.8720, "relay-be-namur", 5),
    ("Mechelen", 51.0259, 4.4776, "relay-be-mechelen", 4),
    ("Charleroi", 50.4108, 4.4446, "relay-be-charleroi", 5),
    ("Hasselt", 50.9307, 5.3375, "relay-be-hasselt", 4),
    ("Kortrijk", 50.8279, 3.2649, "relay-be-kortrijk", 3),
    ("Ostend", 51.2254, 2.9199, "relay-be-ostend", 3),
    ("Mons", 50.4542, 3.9566, "relay-be-mons", 3),
    ("Aalst", 50.9383, 4.0393, "relay-be-aalst", 3),
    ("Tournai", 50.6058, 3.3881, "relay-be-tournai", 2),
    ("Arlon", 49.6834, 5.8166, "relay-be-arlon", 2),
    ("Sint-Niklaas", 51.1564, 4.1573, "relay-be-sint-niklaas", 2),
    ("Roeselare", 50.9469, 3.1244, "relay-be-roeselare", 2),
    ("Verviers", 50.5883, 5.8631, "relay-be-verviers", 2),
    ("Genk", 50.9650, 5.5025, "relay-be-genk", 2),
    ("Turnhout", 51.3225, 4.9484, "relay-be-turnhout", 2),
    ("La Louviere", 50.4712, 4.1858, "relay-be-la-louviere", 2),
    ("Wavre", 50.7157, 4.6113, "relay-be-wavre", 2),
    ("Mouscron", 50.7426, 3.2190, "relay-be-mouscron", 2),
    ("Dendermonde", 51.0284, 4.1004, "relay-be-dendermonde", 2),
    ("Seraing", 50.5833, 5.5000, "relay-be-seraing", 1),
]

def jitter(lat, lng, radius_km=15.0):
    """Add random offset within radius_km using polar coordinates for even distribution."""
    angle = random.uniform(0, 2 * math.pi)
    dist = radius_km * math.sqrt(random.random())  # sqrt for uniform area distribution
    dlat = dist * math.cos(angle) / 111.0
    dlng = dist * math.sin(angle) / (111.0 * math.cos(math.radians(lat)))
    return round(lat + dlat, 5), round(lng + dlng, 5)

def generate_identities(count, name_pool, start_idx=0):
    """Generate count identities distributed across Belgian cities."""
    identities = []
    names_used = set()

    # Build weighted city list
    weighted_cities = []
    for city, lat, lng, relay, weight in CITIES:
        weighted_cities.extend([(city, lat, lng, relay)] * weight)

    for i in range(count):
        # Pick a name
        idx = (start_idx + i) % len(name_pool)
        base_name = name_pool[idx]

        # Ensure unique
        name = base_name
        suffix = 2
        while name in names_used:
            name = f"{base_name}-{suffix}"
            suffix += 1
        names_used.add(name)

        # Pick a city (weighted)
        city, clat, clng, relay = random.choice(weighted_cities)
        lat, lng = jitter(clat, clng, radius_km=15.0)

        # Site = the location where this node lives.
        # Households: site = family home (1-2 nodes share a site).
        # Businesses: site = business location (1-3 nodes share a site).
        import hashlib
        site_id = hashlib.sha256(f"site-{name}".encode()).hexdigest()[:16]
        is_business = name in BUSINESSES
        site_type = "business" if is_business else "household"

        identities.append({
            "name": name,
            "city": city,
            "country": "BE",
            "lat": lat,
            "lng": lng,
            "relay": f"https://{relay}.macula.io:4433",
            "site": {
                "site_id": site_id,
                "name": name.replace("-", " ").title(),
                "city": city,
                "country": "BE",
                "lat": lat,
                "lng": lng,
                "site_type": site_type
            }
        })

    return identities

# Generate pools
all_names = FAMILIES + BUSINESSES
random.shuffle(all_names)

out_dir = os.path.join(os.path.dirname(__file__), "..", "daemon", "stubs")

# beam00: 50 identities
ids_00 = generate_identities(50, all_names, 0)
with open(os.path.join(out_dir, "stubs-beam00.json"), "w") as f:
    json.dump(ids_00, f, indent=2)
print(f"beam00: {len(ids_00)} identities")

# beam01: 100 identities
ids_01 = generate_identities(100, all_names, 50)
with open(os.path.join(out_dir, "stubs-beam01.json"), "w") as f:
    json.dump(ids_01, f, indent=2)
print(f"beam01: {len(ids_01)} identities")

# beam02: 100 identities
ids_02 = generate_identities(100, all_names, 150)
with open(os.path.join(out_dir, "stubs-beam02.json"), "w") as f:
    json.dump(ids_02, f, indent=2)
print(f"beam02: {len(ids_02)} identities")

# beam03: 100 identities
ids_03 = generate_identities(100, all_names, 250)
with open(os.path.join(out_dir, "stubs-beam03.json"), "w") as f:
    json.dump(ids_03, f, indent=2)
print(f"beam03: {len(ids_03)} identities")

# Summary
all_ids = ids_00 + ids_01 + ids_02 + ids_03
cities = {}
for i in all_ids:
    cities[i["city"]] = cities.get(i["city"], 0) + 1
print(f"\nTotal: {len(all_ids)} identities across {len(cities)} cities")
for c in sorted(cities, key=lambda x: -cities[x])[:10]:
    print(f"  {c}: {cities[c]}")
