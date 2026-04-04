#!/bin/bash
# Generate Eastern Front relay identities for the invasion scenario.
#
# ~75 identities across Ukraine, Poland, Baltics, Romania/Moldova.
# Designed for dense coverage along the NATO eastern flank.
#
# Usage:
#   ./scripts/generate-eastern-front.sh                        # with IPv6
#   ./scripts/generate-eastern-front.sh --prefix 2600:3c0e:e001:ec  # custom prefix
#   ./scripts/generate-eastern-front.sh --offset 200           # start at ::200 (after BeNeLux)
#
# Output: comma-separated identity string (append to MACULA_RELAY_IDENTITIES)

set -euo pipefail

IPV6_PREFIX="${1:-2600:3c0e:e001:ec}"
# Start after BeNeLux range (::100-::163), leave gap
OFFSET="${2:-512}"  # 0x200
INDEX=$OFFSET

# ── Ukraine (40 cities) ───────────────────────────────────────────
# Dense coverage: major cities + east-west corridor for barrage scenario
UA=(
  # Major cities (targets)
  "relay-ua-kyiv.macula.io|Kyiv|UA|50.4501|30.5234"
  "relay-ua-kharkiv.macula.io|Kharkiv|UA|49.9935|36.2304"
  "relay-ua-odessa.macula.io|Odessa|UA|46.4825|30.7233"
  "relay-ua-dnipro.macula.io|Dnipro|UA|48.4647|35.0462"
  "relay-ua-lviv.macula.io|Lviv|UA|49.8397|24.0297"
  "relay-ua-zaporizhzhia.macula.io|Zaporizhzhia|UA|47.8388|35.1396"
  # Western Ukraine (survival zone)
  "relay-ua-ternopil.macula.io|Ternopil|UA|49.5535|25.5948"
  "relay-ua-ivano-frankivsk.macula.io|Ivano-Frankivsk|UA|48.9226|24.7111"
  "relay-ua-uzhhorod.macula.io|Uzhhorod|UA|48.6208|22.2879"
  "relay-ua-lutsk.macula.io|Lutsk|UA|50.7472|25.3254"
  "relay-ua-rivne.macula.io|Rivne|UA|50.6199|26.2516"
  "relay-ua-khmelnytskyi.macula.io|Khmelnytskyi|UA|49.4230|26.9871"
  "relay-ua-vinnytsia.macula.io|Vinnytsia|UA|49.2331|28.4682"
  "relay-ua-chernivtsi.macula.io|Chernivtsi|UA|48.2920|25.9358"
  # Central corridor (barrage path)
  "relay-ua-zhytomyr.macula.io|Zhytomyr|UA|50.2547|28.6587"
  "relay-ua-cherkasy.macula.io|Cherkasy|UA|49.4444|32.0598"
  "relay-ua-poltava.macula.io|Poltava|UA|49.5883|34.5514"
  "relay-ua-kirovohrad.macula.io|Kropyvnytskyi|UA|48.5079|32.2623"
  # Northern (Chernihiv-Sumy line)
  "relay-ua-chernihiv.macula.io|Chernihiv|UA|51.4982|31.2893"
  "relay-ua-sumy.macula.io|Sumy|UA|50.9077|34.7981"
  # Southern coast
  "relay-ua-mykolaiv.macula.io|Mykolaiv|UA|46.9750|31.9946"
  "relay-ua-kherson.macula.io|Kherson|UA|46.6354|32.6169"
  # Eastern front (first to fall)
  "relay-ua-donetsk.macula.io|Donetsk|UA|48.0159|37.8029"
  "relay-ua-luhansk.macula.io|Luhansk|UA|48.5740|39.3078"
  "relay-ua-mariupol.macula.io|Mariupol|UA|47.0958|37.5494"
  "relay-ua-kramatorsk.macula.io|Kramatorsk|UA|48.7364|37.5717"
  "relay-ua-severodonetsk.macula.io|Severodonetsk|UA|48.9484|38.4931"
  # Fill gaps for barrage density
  "relay-ua-bila-tserkva.macula.io|Bila Tserkva|UA|49.7953|30.1159"
  "relay-ua-uman.macula.io|Uman|UA|48.7479|30.2218"
  "relay-ua-kremenchuk.macula.io|Kremenchuk|UA|49.0655|33.4117"
  "relay-ua-kamianske.macula.io|Kamianske|UA|48.5182|34.6137"
  "relay-ua-melitopol.macula.io|Melitopol|UA|46.8489|35.3653"
  "relay-ua-berdyansk.macula.io|Berdyansk|UA|46.7586|36.7914"
  "relay-ua-nikopol.macula.io|Nikopol|UA|47.5715|34.3942"
  "relay-ua-pavlohrad.macula.io|Pavlohrad|UA|48.5333|35.8708"
  "relay-ua-konotop.macula.io|Konotop|UA|51.2400|33.2056"
  "relay-ua-nizhyn.macula.io|Nizhyn|UA|51.0498|31.8862"
  "relay-ua-shepetivka.macula.io|Shepetivka|UA|50.1833|27.0667"
  "relay-ua-korosten.macula.io|Korosten|UA|50.9517|28.6350"
  "relay-ua-stryi.macula.io|Stryi|UA|49.2617|23.8497"
)

# ── Poland (15 cities) ────────────────────────────────────────────
# NATO border — traffic reroutes here when Ukraine relays fall
PL=(
  "relay-pl-lublin.macula.io|Lublin|PL|51.2465|22.5684"
  "relay-pl-rzeszow.macula.io|Rzeszow|PL|50.0412|21.9991"
  "relay-pl-bialystok.macula.io|Bialystok|PL|53.1325|23.1688"
  "relay-pl-szczecin.macula.io|Szczecin|PL|53.4285|14.5528"
  "relay-pl-katowice.macula.io|Katowice|PL|50.2649|19.0238"
  "relay-pl-olsztyn.macula.io|Olsztyn|PL|53.7784|20.4801"
  "relay-pl-torun.macula.io|Torun|PL|53.0138|18.5984"
  "relay-pl-bydgoszcz.macula.io|Bydgoszcz|PL|53.1235|18.0084"
  "relay-pl-radom.macula.io|Radom|PL|51.4027|21.1471"
  "relay-pl-poznan.macula.io|Poznan|PL|52.4064|16.9252"
  "relay-pl-lodz.macula.io|Lodz|PL|51.7592|19.4560"
  "relay-pl-chelm.macula.io|Chelm|PL|51.1431|23.4716"
  "relay-pl-przemysl.macula.io|Przemysl|PL|49.7838|22.7678"
  "relay-pl-zamosc.macula.io|Zamosc|PL|50.7230|23.2520"
  "relay-pl-sanok.macula.io|Sanok|PL|49.5568|22.2057"
)

# ── Baltics (10 cities) ───────────────────────────────────────────
BA=(
  "relay-ee-tartu.macula.io|Tartu|EE|58.3780|26.7290"
  "relay-ee-parnu.macula.io|Parnu|EE|58.3859|24.4971"
  "relay-lv-liepaja.macula.io|Liepaja|LV|56.5047|21.0109"
  "relay-lv-daugavpils.macula.io|Daugavpils|LV|55.8749|26.5362"
  "relay-lt-kaunas.macula.io|Kaunas|LT|54.8985|23.9036"
  "relay-lt-klaipeda.macula.io|Klaipeda|LT|55.7033|21.1443"
  "relay-lt-siauliai.macula.io|Siauliai|LT|55.9349|23.3137"
  "relay-lt-panevezys.macula.io|Panevezys|LT|55.7348|24.3575"
  "relay-lt-alytus.macula.io|Alytus|LT|54.3963|24.0459"
  "relay-lt-marijampole.macula.io|Marijampole|LT|54.5594|23.3500"
)

# ── Romania + Moldova (10 cities) ─────────────────────────────────
ROMO=(
  "relay-ro-cluj.macula.io|Cluj-Napoca|RO|46.7712|23.6236"
  "relay-ro-timisoara.macula.io|Timisoara|RO|45.7489|21.2087"
  "relay-ro-iasi.macula.io|Iasi|RO|47.1585|27.6014"
  "relay-ro-constanta.macula.io|Constanta|RO|44.1598|28.6348"
  "relay-ro-brasov.macula.io|Brasov|RO|45.6427|25.5887"
  "relay-ro-galati.macula.io|Galati|RO|45.4353|28.0080"
  "relay-ro-craiova.macula.io|Craiova|RO|44.3302|23.7949"
  "relay-md-chisinau.macula.io|Chisinau|MD|47.0105|28.8638"
  "relay-md-balti.macula.io|Balti|MD|47.7617|27.9289"
  "relay-md-tiraspol.macula.io|Tiraspol|MD|46.8403|29.6433"
)

# ── Combine and output ────────────────────────────────────────────
ALL=("${UA[@]}" "${PL[@]}" "${BA[@]}" "${ROMO[@]}")
TOTAL=${#ALL[@]}

echo "# Eastern Front relay identities: ${TOTAL} cities" >&2
echo "# UA:${#UA[@]} PL:${#PL[@]} BA:${#BA[@]} RO/MD:${#ROMO[@]}" >&2
echo "# IPv6 range: ${IPV6_PREFIX}::$(printf '%x' $OFFSET)-::$(printf '%x' $((OFFSET + TOTAL - 1)))" >&2
echo "" >&2

RESULT=""
for entry in "${ALL[@]}"; do
  IFS='|' read -r host city country lat lng <<< "$entry"
  hex=$(printf '%x' $INDEX)
  IDENTITY="${host}/${city}/${country}/${lat}/${lng}/${IPV6_PREFIX}::${hex}"
  if [ -z "$RESULT" ]; then
    RESULT="$IDENTITY"
  else
    RESULT="${RESULT},${IDENTITY}"
  fi
  INDEX=$((INDEX + 1))
done

echo "$RESULT"
