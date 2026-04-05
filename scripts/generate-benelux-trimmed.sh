#!/bin/bash
# Generate a trimmed BeNeLux relay identity list (~100 cities).
#
# Selection criteria:
#   - All provincial/regional capitals
#   - Cities > ~30K population
#   - Enough geographic spread to cover the map
#
# Output: comma-separated identity string for MACULA_RELAY_IDENTITIES
#
# Usage: ./scripts/generate-benelux-trimmed.sh

set -euo pipefail

# ── Belgium (40 cities) ───────────────────────────────────────────
# All 10 provincial capitals + major cities + geographic coverage
BE_CITIES=(
  # Provincial capitals (10)
  "relay-be-brussels.macula.io:Brussels:BE:50.8503:4.3517"
  "relay-be-antwerp.macula.io:Antwerp:BE:51.2194:4.4025"
  "relay-be-ghent.macula.io:Ghent:BE:51.0543:3.7174"
  "relay-be-bruges.macula.io:Bruges:BE:51.2093:3.2247"
  "relay-be-liege.macula.io:Liege:BE:50.6292:5.5797"
  "relay-be-leuven.macula.io:Leuven:BE:50.8798:4.7005"
  "relay-be-namur.macula.io:Namur:BE:50.4674:4.872"
  "relay-be-hasselt.macula.io:Hasselt:BE:50.9307:5.3375"
  "relay-be-arlon.macula.io:Arlon:BE:49.6834:5.8166"
  "relay-be-wavre.macula.io:Wavre:BE:50.7157:4.6113"
  # Major cities >30K (15)
  "relay-be-charleroi.macula.io:Charleroi:BE:50.4108:4.4446"
  "relay-be-mechelen.macula.io:Mechelen:BE:51.0259:4.4776"
  "relay-be-kortrijk.macula.io:Kortrijk:BE:50.8279:3.2649"
  "relay-be-ostend.macula.io:Ostend:BE:51.2254:2.9199"
  "relay-be-mons.macula.io:Mons:BE:50.4542:3.9566"
  "relay-be-aalst.macula.io:Aalst:BE:50.9383:4.0393"
  "relay-be-tournai.macula.io:Tournai:BE:50.6058:3.3881"
  "relay-be-sint-niklaas.macula.io:Sint-Niklaas:BE:51.1564:4.1573"
  "relay-be-roeselare.macula.io:Roeselare:BE:50.9469:3.1244"
  "relay-be-verviers.macula.io:Verviers:BE:50.5883:5.8631"
  "relay-be-genk.macula.io:Genk:BE:50.965:5.5025"
  "relay-be-turnhout.macula.io:Turnhout:BE:51.3225:4.9484"
  "relay-be-la-louviere.macula.io:La Louviere:BE:50.4712:4.1858"
  "relay-be-mouscron.macula.io:Mouscron:BE:50.7426:3.219"
  "relay-be-seraing.macula.io:Seraing:BE:50.5833:5.5"
  # Geographic spread (15)
  "relay-be-ypres.macula.io:Ypres:BE:50.8519:2.8858"
  "relay-be-halle.macula.io:Halle:BE:50.7336:4.2345"
  "relay-be-vilvoorde.macula.io:Vilvoorde:BE:50.9278:4.4248"
  "relay-be-tongeren.macula.io:Tongeren:BE:50.7805:5.4646"
  "relay-be-sint-truiden.macula.io:Sint-Truiden:BE:50.8167:5.1833"
  "relay-be-diest.macula.io:Diest:BE:50.9893:5.0509"
  "relay-be-geel.macula.io:Geel:BE:51.1618:4.9898"
  "relay-be-mol.macula.io:Mol:BE:51.1897:5.1147"
  "relay-be-lommel.macula.io:Lommel:BE:51.2307:5.3144"
  "relay-be-eeklo.macula.io:Eeklo:BE:51.1872:3.5567"
  "relay-be-dendermonde.macula.io:Dendermonde:BE:51.0284:4.1004"
  "relay-be-oudenaarde.macula.io:Oudenaarde:BE:50.8443:3.6067"
  "relay-be-zaventem.macula.io:Zaventem:BE:50.8833:4.4667"
  "relay-be-maasmechelen.macula.io:Maasmechelen:BE:50.9622:5.6897"
  "relay-be-hoogstraten.macula.io:Hoogstraten:BE:51.3977:4.762"
)

# ── Netherlands (48 cities) ───────────────────────────────────────
# All 12 provincial capitals + major cities + geographic coverage
NL_CITIES=(
  # Provincial capitals (12)
  "relay-nl-amsterdam.macula.io:Amsterdam:NL:52.3676:4.9041"
  "relay-nl-the-hague.macula.io:The Hague:NL:52.0705:4.3007"
  "relay-nl-utrecht.macula.io:Utrecht:NL:52.0907:5.1214"
  "relay-nl-groningen.macula.io:Groningen:NL:53.2194:6.5665"
  "relay-nl-arnhem.macula.io:Arnhem:NL:51.9851:5.8987"
  "relay-nl-den-bosch.macula.io:Den Bosch:NL:51.6978:5.3037"
  "relay-nl-maastricht.macula.io:Maastricht:NL:50.8514:5.691"
  "relay-nl-leeuwarden.macula.io:Leeuwarden:NL:53.2012:5.7999"
  "relay-nl-zwolle.macula.io:Zwolle:NL:52.5168:6.083"
  "relay-nl-middelburg.macula.io:Middelburg:NL:51.4988:3.6136"
  "relay-nl-haarlem.macula.io:Haarlem:NL:52.3874:4.6462"
  "relay-nl-lelystad.macula.io:Lelystad:NL:52.5185:5.4714"
  # Major cities >50K (20)
  "relay-nl-rotterdam.macula.io:Rotterdam:NL:51.9244:4.4777"
  "relay-nl-eindhoven.macula.io:Eindhoven:NL:51.4416:5.4697"
  "relay-nl-tilburg.macula.io:Tilburg:NL:51.5555:5.0913"
  "relay-nl-almere.macula.io:Almere:NL:52.3508:5.2647"
  "relay-nl-breda.macula.io:Breda:NL:51.5719:4.7683"
  "relay-nl-nijmegen.macula.io:Nijmegen:NL:51.8126:5.8372"
  "relay-nl-apeldoorn.macula.io:Apeldoorn:NL:52.2112:5.9699"
  "relay-nl-enschede.macula.io:Enschede:NL:52.2215:6.8937"
  "relay-nl-amersfoort.macula.io:Amersfoort:NL:52.1561:5.3878"
  "relay-nl-leiden.macula.io:Leiden:NL:52.1601:4.497"
  "relay-nl-dordrecht.macula.io:Dordrecht:NL:51.8133:4.6901"
  "relay-nl-zoetermeer.macula.io:Zoetermeer:NL:52.0575:4.4931"
  "relay-nl-delft.macula.io:Delft:NL:52.0116:4.3571"
  "relay-nl-deventer.macula.io:Deventer:NL:52.251:6.1598"
  "relay-nl-helmond.macula.io:Helmond:NL:51.4795:5.6611"
  "relay-nl-venlo.macula.io:Venlo:NL:51.3704:6.1724"
  "relay-nl-heerlen.macula.io:Heerlen:NL:50.8882:5.9793"
  "relay-nl-ede.macula.io:Ede:NL:52.0478:5.6597"
  "relay-nl-gouda.macula.io:Gouda:NL:52.0115:4.7105"
  "relay-nl-hilversum.macula.io:Hilversum:NL:52.2292:5.1765"
  # Geographic spread (16)
  "relay-nl-emmen.macula.io:Emmen:NL:52.7862:6.8999"
  "relay-nl-assen.macula.io:Assen:NL:52.9929:6.5642"
  "relay-nl-hengelo.macula.io:Hengelo:NL:52.2661:6.7939"
  "relay-nl-roosendaal.macula.io:Roosendaal:NL:51.5308:4.4653"
  "relay-nl-sittard.macula.io:Sittard:NL:51.0004:5.8696"
  "relay-nl-vlissingen.macula.io:Vlissingen:NL:51.4536:3.5714"
  "relay-nl-terneuzen.macula.io:Terneuzen:NL:51.3308:3.8278"
  "relay-nl-bergen-op-zoom.macula.io:Bergen-op-Zoom:NL:51.495:4.2889"
  "relay-nl-harderwijk.macula.io:Harderwijk:NL:52.3425:5.6208"
  "relay-nl-kampen.macula.io:Kampen:NL:52.555:5.9108"
  "relay-nl-sneek.macula.io:Sneek:NL:53.0333:5.66"
  "relay-nl-heerenveen.macula.io:Heerenveen:NL:52.9596:5.925"
  "relay-nl-drachten.macula.io:Drachten:NL:53.1064:6.0989"
  "relay-nl-hoorn.macula.io:Hoorn:NL:52.6425:5.0597"
  "relay-nl-oss.macula.io:Oss:NL:51.7651:5.5184"
  "relay-nl-doetinchem.macula.io:Doetinchem:NL:51.9647:6.2886"
)

# ── Luxembourg (12 cities — keep all, tiny country) ──────────────
LU_CITIES=(
  "relay-lu-luxembourg.macula.io:Luxembourg:LU:49.6117:6.1319"
  "relay-lu-esch-sur-alzette.macula.io:Esch-sur-Alzette:LU:49.4958:5.9806"
  "relay-lu-differdange.macula.io:Differdange:LU:49.5242:5.8914"
  "relay-lu-dudelange.macula.io:Dudelange:LU:49.4806:6.0875"
  "relay-lu-ettelbruck.macula.io:Ettelbruck:LU:49.8472:6.1042"
  "relay-lu-diekirch.macula.io:Diekirch:LU:49.8683:6.1597"
  "relay-lu-wiltz.macula.io:Wiltz:LU:49.9661:5.9333"
  "relay-lu-echternach.macula.io:Echternach:LU:49.8118:6.4219"
  "relay-lu-remich.macula.io:Remich:LU:49.545:6.3667"
  "relay-lu-grevenmacher.macula.io:Grevenmacher:LU:49.6808:6.4406"
  "relay-lu-vianden.macula.io:Vianden:LU:49.935:6.2089"
  "relay-lu-clervaux.macula.io:Clervaux:LU:50.0542:6.0289"
)

# ── Combine and output ────────────────────────────────────────────
ALL_CITIES=("${BE_CITIES[@]}" "${NL_CITIES[@]}" "${LU_CITIES[@]}")
TOTAL=${#ALL_CITIES[@]}

echo "# BeNeLux trimmed relay identities: ${TOTAL} cities" >&2
echo "# BE: ${#BE_CITIES[@]}, NL: ${#NL_CITIES[@]}, LU: ${#LU_CITIES[@]}" >&2
echo "" >&2

# Output as comma-separated string (for MACULA_RELAY_IDENTITIES)
IFS=','
echo "${ALL_CITIES[*]}"
