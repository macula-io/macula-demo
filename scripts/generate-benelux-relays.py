#!/usr/bin/env python3
"""Generate expanded BeNeLux relay identities for the multi-tenant relay config.

Outputs MACULA_RELAY_IDENTITIES env var format for relay00:
  hostname:city:country:lat:lng,hostname2:city2:country2:lat2:lng2,...

Run: python3 scripts/generate-benelux-relays.py > /tmp/benelux-relays.env
"""

import hashlib

# ── Belgian municipalities (100+) ────────────────────────────────
BE_CITIES = [
    # Major cities
    ("Brussels", 50.8503, 4.3517), ("Antwerp", 51.2194, 4.4025),
    ("Ghent", 51.0543, 3.7174), ("Bruges", 51.2093, 3.2247),
    ("Liege", 50.6292, 5.5797), ("Leuven", 50.8798, 4.7005),
    ("Namur", 50.4674, 4.8720), ("Charleroi", 50.4108, 4.4446),
    ("Mechelen", 51.0259, 4.4776), ("Hasselt", 50.9307, 5.3375),
    ("Kortrijk", 50.8279, 3.2649), ("Ostend", 51.2254, 2.9199),
    ("Mons", 50.4542, 3.9566), ("Aalst", 50.9383, 4.0393),
    ("Tournai", 50.6058, 3.3881), ("Arlon", 49.6834, 5.8166),
    ("Sint-Niklaas", 51.1564, 4.1573), ("Roeselare", 50.9469, 3.1244),
    ("Verviers", 50.5883, 5.8631), ("Genk", 50.9650, 5.5025),
    ("Turnhout", 51.3225, 4.9484), ("La Louviere", 50.4712, 4.1858),
    ("Wavre", 50.7157, 4.6113), ("Mouscron", 50.7426, 3.2190),
    ("Dendermonde", 51.0284, 4.1004), ("Seraing", 50.5833, 5.5000),
    # Medium towns
    ("Lier", 51.1311, 4.5700), ("Diest", 50.9893, 5.0509),
    ("Tongeren", 50.7805, 5.4646), ("Waregem", 50.8789, 3.4244),
    ("Ypres", 50.8519, 2.8858), ("Tienen", 50.8072, 4.9368),
    ("Herentals", 51.1765, 4.8343), ("Mol", 51.1897, 5.1147),
    ("Geraardsbergen", 50.7714, 3.8819), ("Halle", 50.7336, 4.2345),
    ("Vilvoorde", 50.9278, 4.4248), ("Zemst", 50.9837, 4.4575),
    ("Boom", 51.0897, 4.3708), ("Wetteren", 51.0012, 3.8831),
    ("Zottegem", 50.8676, 3.8103), ("Oudenaarde", 50.8443, 3.6067),
    ("Deinze", 50.9833, 3.5333), ("Ninove", 50.8370, 4.0244),
    ("Eeklo", 51.1872, 3.5567), ("Lokeren", 51.1043, 3.9890),
    ("Temse", 51.1274, 4.2111), ("Beveren", 51.2108, 4.2572),
    ("Sint-Truiden", 50.8167, 5.1833), ("Bilzen", 50.8728, 5.5178),
    ("Maaseik", 51.0983, 5.7857), ("Peer", 51.1307, 5.4577),
    ("Lommel", 51.2307, 5.3144), ("Heusden-Zolder", 51.0356, 5.2844),
    ("Beringen", 51.0492, 5.2261), ("Maasmechelen", 50.9622, 5.6897),
    ("Aarschot", 50.9870, 4.8300), ("Geel", 51.1618, 4.9898),
    ("Hoogstraten", 51.3977, 4.7620), ("Balen", 51.1685, 5.1677),
    ("Zele", 51.0687, 4.0386), ("Hamme", 51.0981, 4.1361),
    ("Bornem", 51.0978, 4.2381), ("Puurs", 51.0725, 4.2867),
    ("Kapellen", 51.3125, 4.4286), ("Brasschaat", 51.2917, 4.4917),
    ("Schoten", 51.2528, 4.5000), ("Wijnegem", 51.2303, 4.5169),
    ("Mortsel", 51.1694, 4.4556), ("Edegem", 51.1583, 4.4417),
    ("Kontich", 51.1306, 4.4500), ("Lint", 51.1250, 4.4917),
    ("Boechout", 51.1583, 4.5000), ("Ranst", 51.1972, 4.5583),
    ("Zoersel", 51.2667, 4.7083), ("Malle", 51.3000, 4.6917),
    ("Zandhoven", 51.2167, 4.6583), ("Essen", 51.4667, 4.4667),
    ("Kalmthout", 51.3833, 4.4000), ("Stabroek", 51.3333, 4.3667),
    ("Brecht", 51.3500, 4.6333), ("Schilde", 51.2417, 4.5833),
    ("Wommelgem", 51.2083, 4.5250), ("Arendonk", 51.3243, 5.0831),
    ("Retie", 51.2666, 5.0833), ("Dessel", 51.2333, 5.1167),
    ("Duffel", 51.0917, 4.5083), ("Berlaar", 51.1167, 4.6500),
    ("Nijlen", 51.1583, 4.6583), ("Heist-op-den-Berg", 51.0833, 4.7333),
    ("Putte", 51.0583, 4.6250), ("Bonheiden", 51.0250, 4.5333),
    ("Beersel", 50.7667, 4.3000), ("Sint-Genesius-Rode", 50.7500, 4.3500),
    ("Hoeilaart", 50.7667, 4.4667), ("Overijse", 50.7750, 4.5333),
    ("Tervuren", 50.8167, 4.5167), ("Zaventem", 50.8833, 4.4667),
    ("Grimbergen", 50.9333, 4.3667), ("Meise", 50.9333, 4.3167),
    ("Wemmel", 50.9000, 4.3167), ("Machelen", 50.9167, 4.4333),
    ("Steenokkerzeel", 50.9167, 4.5167), ("Kampenhout", 50.9500, 4.5667),
    ("Oud-Heverlee", 50.8333, 4.6667), ("Bertem", 50.8583, 4.6167),
]

# ── Dutch cities (80+) ──────────────────────────────────────────
NL_CITIES = [
    # Major
    ("Amsterdam", 52.3676, 4.9041), ("Rotterdam", 51.9244, 4.4777),
    ("The Hague", 52.0705, 4.3007), ("Utrecht", 52.0907, 5.1214),
    ("Eindhoven", 51.4416, 5.4697), ("Tilburg", 51.5555, 5.0913),
    ("Groningen", 53.2194, 6.5665), ("Almere", 52.3508, 5.2647),
    ("Breda", 51.5719, 4.7683), ("Nijmegen", 51.8126, 5.8372),
    ("Apeldoorn", 52.2112, 5.9699), ("Arnhem", 51.9851, 5.8987),
    ("Haarlem", 52.3874, 4.6462), ("Enschede", 52.2215, 6.8937),
    ("Amersfoort", 52.1561, 5.3878), ("Zaanstad", 52.4492, 4.8269),
    ("Den Bosch", 51.6978, 5.3037), ("Haarlemmermeer", 52.3026, 4.6925),
    ("Leiden", 52.1601, 4.4970), ("Zoetermeer", 52.0575, 4.4931),
    ("Dordrecht", 51.8133, 4.6901), ("Ede", 52.0478, 5.6597),
    ("Delft", 52.0116, 4.3571), ("Leeuwarden", 53.2012, 5.7999),
    ("Deventer", 52.2510, 6.1598), ("Sittard", 51.0004, 5.8696),
    ("Roosendaal", 51.5308, 4.4653), ("Helmond", 51.4795, 5.6611),
    ("Maastricht", 50.8514, 5.6910), ("Venlo", 51.3704, 6.1724),
    ("Heerlen", 50.8882, 5.9793), ("Oss", 51.7651, 5.5184),
    ("Gouda", 52.0115, 4.7105), ("Zwolle", 52.5168, 6.0830),
    # Medium
    ("Emmen", 52.7862, 6.8999), ("Assen", 52.9929, 6.5642),
    ("Hilversum", 52.2292, 5.1765), ("Purmerend", 52.5050, 4.9577),
    ("Schiedam", 51.9175, 4.3889), ("Vlaardingen", 51.9125, 4.3419),
    ("Spijkenisse", 51.8450, 4.3289), ("Hoorn", 52.6425, 5.0597),
    ("Lelystad", 52.5185, 5.4714), ("Veenendaal", 52.0283, 5.5589),
    ("Zeist", 52.0889, 5.2322), ("Nieuwegein", 52.0286, 5.0853),
    ("IJsselstein", 52.0228, 5.0444), ("Woerden", 52.0853, 4.8831),
    ("Alphen", 52.1297, 4.6583), ("Katwijk", 52.2014, 4.4178),
    ("Leidschendam", 52.0875, 4.3922), ("Rijswijk", 52.0361, 4.3264),
    ("Voorburg", 52.0700, 4.3600), ("Wassenaar", 52.1467, 4.3975),
    ("Middelburg", 51.4988, 3.6136), ("Vlissingen", 51.4536, 3.5714),
    ("Goes", 51.5042, 3.8889), ("Terneuzen", 51.3308, 3.8278),
    ("Bergen-op-Zoom", 51.4950, 4.2889), ("Waalwijk", 51.6881, 5.0728),
    ("Cuijk", 51.7283, 5.8783), ("Boxmeer", 51.6472, 5.9461),
    ("Veghel", 51.6167, 5.5500), ("Uden", 51.6597, 5.6175),
    ("Doetinchem", 51.9647, 6.2886), ("Winterswijk", 51.9722, 6.7208),
    ("Harderwijk", 52.3425, 5.6208), ("Ermelo", 52.3000, 5.6167),
    ("Nunspeet", 52.3756, 5.7856), ("Elburg", 52.4433, 5.8367),
    ("Kampen", 52.5550, 5.9108), ("Meppel", 52.6964, 6.1944),
    ("Hoogeveen", 52.7225, 6.4764), ("Coevorden", 52.6614, 6.7408),
    ("Hengelo", 52.2661, 6.7939), ("Almelo", 52.3567, 6.6628),
    ("Oldenzaal", 52.3133, 6.9292), ("Rijssen", 52.3097, 6.5186),
    ("Hardenberg", 52.5733, 6.6189), ("Steenwijk", 52.7864, 6.1186),
    ("Sneek", 53.0333, 5.6600), ("Heerenveen", 52.9596, 5.9250),
    ("Drachten", 53.1064, 6.0989),
]

# ── Luxembourg cities (12) ──────────────────────────────────────
LU_CITIES = [
    ("Luxembourg", 49.6117, 6.1319), ("Esch-sur-Alzette", 49.4958, 5.9806),
    ("Differdange", 49.5242, 5.8914), ("Dudelange", 49.4806, 6.0875),
    ("Ettelbruck", 49.8472, 6.1042), ("Diekirch", 49.8683, 6.1597),
    ("Wiltz", 49.9661, 5.9333), ("Echternach", 49.8118, 6.4219),
    ("Remich", 49.5450, 6.3667), ("Grevenmacher", 49.6808, 6.4406),
    ("Vianden", 49.9350, 6.2089), ("Clervaux", 50.0542, 6.0289),
]


def hostname(city, country):
    """Generate relay hostname from city + country."""
    slug = city.lower().replace(" ", "-").replace("'", "").replace(".", "")
    return f"relay-{country.lower()}-{slug}.macula.io"


def generate_relay_identities():
    """Generate all BeNeLux relay identity strings."""
    identities = []
    for city, lat, lng in BE_CITIES:
        identities.append(f"{hostname(city, 'BE')}:{city}:BE:{lat}:{lng}")
    for city, lat, lng in NL_CITIES:
        identities.append(f"{hostname(city, 'NL')}:{city}:NL:{lat}:{lng}")
    for city, lat, lng in LU_CITIES:
        identities.append(f"{hostname(city, 'LU')}:{city}:LU:{lat}:{lng}")
    return identities


if __name__ == "__main__":
    identities = generate_relay_identities()
    print(f"# {len(identities)} BeNeLux relay identities")
    print(f"# BE: {len(BE_CITIES)}, NL: {len(NL_CITIES)}, LU: {len(LU_CITIES)}")
    print(f"MACULA_RELAY_IDENTITIES={','.join(identities)}")
