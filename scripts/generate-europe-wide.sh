#!/bin/bash
# Generate Europe-wide relay identities for the Amsterdam box.
# Replaces the old BeNeLux-heavy distribution with even coverage.
#
# 175 identities across all of Europe (slight BeNeLux concentration).
# IPv6 addresses sequential from ::100.
#
# Format: hostname/city/country/lat/lng[/ipv6_addr]
#
# Usage:
#   ./scripts/generate-europe-wide.sh                    # with IPv6
#   ./scripts/generate-europe-wide.sh --no-ipv6          # without
#   ./scripts/generate-europe-wide.sh --prefix 2600:3c0e:e001:ec

set -euo pipefail

IPV6_PREFIX="${2:-2600:3c0e:e001:ec}"
NO_IPV6="${1:-}"
INDEX=256  # Start at ::100

emit() {
  local host="$1" city="$2" country="$3" lat="$4" lng="$5"
  if [ "${NO_IPV6}" = "--no-ipv6" ]; then
    echo -n "${host}/${city}/${country}/${lat}/${lng}"
  else
    local hex
    hex=$(printf '%x' $INDEX)
    echo -n "${host}/${city}/${country}/${lat}/${lng}/${IPV6_PREFIX}::${hex}"
    INDEX=$((INDEX + 1))
  fi
}

FIRST=1
output() {
  if [ "$FIRST" -eq 1 ]; then
    FIRST=0
  else
    echo -n ","
  fi
  emit "$@"
}

# ── BeNeLux (25) — slight concentration ──────────────────────────
output "relay-be-brussels.macula.io" "Brussels" "BE" "50.8503" "4.3517"
output "relay-be-antwerp.macula.io" "Antwerp" "BE" "51.2194" "4.4025"
output "relay-be-ghent.macula.io" "Ghent" "BE" "51.0543" "3.7174"
output "relay-be-liege.macula.io" "Liege" "BE" "50.6292" "5.5797"
output "relay-be-bruges.macula.io" "Bruges" "BE" "51.2093" "3.2247"
output "relay-be-leuven.macula.io" "Leuven" "BE" "50.8798" "4.7005"
output "relay-be-namur.macula.io" "Namur" "BE" "50.4674" "4.8712"
output "relay-be-mons.macula.io" "Mons" "BE" "50.4542" "3.9523"
output "relay-be-charleroi.macula.io" "Charleroi" "BE" "50.4108" "4.4446"
output "relay-be-mechelen.macula.io" "Mechelen" "BE" "51.0259" "4.4776"
output "relay-nl-amsterdam.macula.io" "Amsterdam" "NL" "52.3676" "4.9041"
output "relay-nl-rotterdam.macula.io" "Rotterdam" "NL" "51.9244" "4.4777"
output "relay-nl-utrecht.macula.io" "Utrecht" "NL" "52.0907" "5.1214"
output "relay-nl-eindhoven.macula.io" "Eindhoven" "NL" "51.4416" "5.4697"
output "relay-nl-groningen.macula.io" "Groningen" "NL" "53.2194" "6.5665"
output "relay-nl-den-haag.macula.io" "Den Haag" "NL" "52.0705" "4.3007"
output "relay-nl-maastricht.macula.io" "Maastricht" "NL" "50.8514" "5.6910"
output "relay-nl-leiden.macula.io" "Leiden" "NL" "52.1601" "4.4970"
output "relay-nl-nijmegen.macula.io" "Nijmegen" "NL" "51.8126" "5.8372"
output "relay-nl-tilburg.macula.io" "Tilburg" "NL" "51.5555" "5.0913"
output "relay-nl-breda.macula.io" "Breda" "NL" "51.5719" "4.7683"
output "relay-nl-arnhem.macula.io" "Arnhem" "NL" "51.9851" "5.8987"
output "relay-lu-luxembourg.macula.io" "Luxembourg" "LU" "49.6117" "6.1300"
output "relay-lu-esch.macula.io" "Esch-sur-Alzette" "LU" "49.4950" "5.9806"
output "relay-lu-differdange.macula.io" "Differdange" "LU" "49.5242" "5.8913"

# ── United Kingdom / Ireland (15) ────────────────────────────────
output "relay-gb-london.macula.io" "London" "GB" "51.5074" "-0.1278"
output "relay-gb-manchester.macula.io" "Manchester" "GB" "53.4808" "-2.2426"
output "relay-gb-birmingham.macula.io" "Birmingham" "GB" "52.4862" "-1.8904"
output "relay-gb-edinburgh.macula.io" "Edinburgh" "GB" "55.9533" "-3.1883"
output "relay-gb-glasgow.macula.io" "Glasgow" "GB" "55.8642" "-4.2518"
output "relay-gb-leeds.macula.io" "Leeds" "GB" "53.8008" "-1.5491"
output "relay-gb-bristol.macula.io" "Bristol" "GB" "51.4545" "-2.5879"
output "relay-gb-liverpool.macula.io" "Liverpool" "GB" "53.4084" "-2.9916"
output "relay-gb-cardiff.macula.io" "Cardiff" "GB" "51.4816" "-3.1791"
output "relay-gb-belfast.macula.io" "Belfast" "GB" "54.5973" "-5.9301"
output "relay-gb-cambridge.macula.io" "Cambridge" "GB" "52.2053" "0.1218"
output "relay-ie-dublin.macula.io" "Dublin" "IE" "53.3498" "-6.2603"
output "relay-ie-cork.macula.io" "Cork" "IE" "51.8985" "-8.4756"
output "relay-ie-galway.macula.io" "Galway" "IE" "53.2707" "-9.0568"
output "relay-ie-limerick.macula.io" "Limerick" "IE" "52.6638" "-8.6267"

# ── France (15) ──────────────────────────────────────────────────
output "relay-fr-paris.macula.io" "Paris" "FR" "48.8566" "2.3522"
output "relay-fr-lyon.macula.io" "Lyon" "FR" "45.7640" "4.8357"
output "relay-fr-marseille.macula.io" "Marseille" "FR" "43.2965" "5.3698"
output "relay-fr-toulouse.macula.io" "Toulouse" "FR" "43.6047" "1.4442"
output "relay-fr-nice.macula.io" "Nice" "FR" "43.7102" "7.2620"
output "relay-fr-nantes.macula.io" "Nantes" "FR" "47.2184" "-1.5536"
output "relay-fr-strasbourg.macula.io" "Strasbourg" "FR" "48.5734" "7.7521"
output "relay-fr-bordeaux.macula.io" "Bordeaux" "FR" "44.8378" "-0.5792"
output "relay-fr-lille.macula.io" "Lille" "FR" "50.6292" "3.0573"
output "relay-fr-rennes.macula.io" "Rennes" "FR" "48.1173" "-1.6778"
output "relay-fr-montpellier.macula.io" "Montpellier" "FR" "43.6108" "3.8767"
output "relay-fr-grenoble.macula.io" "Grenoble" "FR" "45.1885" "5.7245"
output "relay-fr-dijon.macula.io" "Dijon" "FR" "47.3220" "5.0415"
output "relay-fr-clermont.macula.io" "Clermont-Ferrand" "FR" "45.7772" "3.0870"
output "relay-fr-tours.macula.io" "Tours" "FR" "47.3941" "0.6848"

# ── Spain / Portugal (12) ────────────────────────────────────────
output "relay-es-madrid.macula.io" "Madrid" "ES" "40.4168" "-3.7038"
output "relay-es-barcelona.macula.io" "Barcelona" "ES" "41.3851" "2.1734"
output "relay-es-valencia.macula.io" "Valencia" "ES" "39.4699" "-0.3763"
output "relay-es-seville.macula.io" "Seville" "ES" "37.3891" "-5.9845"
output "relay-es-bilbao.macula.io" "Bilbao" "ES" "43.2630" "-2.9350"
output "relay-es-malaga.macula.io" "Malaga" "ES" "36.7213" "-4.4214"
output "relay-es-zaragoza.macula.io" "Zaragoza" "ES" "41.6488" "-0.8891"
output "relay-es-palma.macula.io" "Palma" "ES" "39.5696" "2.6502"
output "relay-pt-lisbon.macula.io" "Lisbon" "PT" "38.7223" "-9.1393"
output "relay-pt-porto.macula.io" "Porto" "PT" "41.1579" "-8.6291"
output "relay-pt-faro.macula.io" "Faro" "PT" "37.0194" "-7.9322"
output "relay-pt-coimbra.macula.io" "Coimbra" "PT" "40.2033" "-8.4103"

# ── Italy (10) ───────────────────────────────────────────────────
output "relay-it-rome.macula.io" "Rome" "IT" "41.9028" "12.4964"
output "relay-it-milan.macula.io" "Milan" "IT" "45.4642" "9.1900"
output "relay-it-naples.macula.io" "Naples" "IT" "40.8518" "14.2681"
output "relay-it-turin.macula.io" "Turin" "IT" "45.0703" "7.6869"
output "relay-it-florence.macula.io" "Florence" "IT" "43.7696" "11.2558"
output "relay-it-bologna.macula.io" "Bologna" "IT" "44.4949" "11.3426"
output "relay-it-venice.macula.io" "Venice" "IT" "45.4408" "12.3155"
output "relay-it-palermo.macula.io" "Palermo" "IT" "38.1157" "13.3615"
output "relay-it-genoa.macula.io" "Genoa" "IT" "44.4056" "8.9463"
output "relay-it-bari.macula.io" "Bari" "IT" "41.1171" "16.8719"

# ── Germany (10) — supplements Nuremberg box's 30 ────────────────
output "relay-de-hamburg.macula.io" "Hamburg" "DE" "53.5511" "9.9937"
output "relay-de-cologne.macula.io" "Cologne" "DE" "50.9375" "6.9603"
output "relay-de-dortmund.macula.io" "Dortmund" "DE" "51.5136" "7.4653"
output "relay-de-dresden.macula.io" "Dresden" "DE" "51.0504" "13.7373"
output "relay-de-leipzig.macula.io" "Leipzig" "DE" "51.3397" "12.3731"
output "relay-de-hannover.macula.io" "Hannover" "DE" "52.3759" "9.7320"
output "relay-de-bremen.macula.io" "Bremen" "DE" "53.0793" "8.8017"
output "relay-de-rostock.macula.io" "Rostock" "DE" "54.0924" "12.0991"
output "relay-de-kiel.macula.io" "Kiel" "DE" "54.3233" "10.1228"
output "relay-de-freiburg.macula.io" "Freiburg" "DE" "47.9990" "7.8421"

# ── Switzerland / Austria (8) ────────────────────────────────────
output "relay-ch-zurich.macula.io" "Zurich" "CH" "47.3769" "8.5417"
output "relay-ch-bern.macula.io" "Bern" "CH" "46.9480" "7.4474"
output "relay-ch-geneva.macula.io" "Geneva" "CH" "46.2044" "6.1432"
output "relay-ch-basel.macula.io" "Basel" "CH" "47.5596" "7.5886"
output "relay-at-vienna.macula.io" "Vienna" "AT" "48.2082" "16.3738"
output "relay-at-graz.macula.io" "Graz" "AT" "47.0707" "15.4395"
output "relay-at-salzburg.macula.io" "Salzburg" "AT" "47.8095" "13.0550"
output "relay-at-innsbruck.macula.io" "Innsbruck" "AT" "47.2692" "11.4041"

# ── Ukraine (40) — kept for Eastern Front narrative ──────────────
output "relay-ua-kyiv.macula.io" "Kyiv" "UA" "50.4501" "30.5234"
output "relay-ua-kharkiv.macula.io" "Kharkiv" "UA" "49.9935" "36.2304"
output "relay-ua-odessa.macula.io" "Odessa" "UA" "46.4825" "30.7233"
output "relay-ua-dnipro.macula.io" "Dnipro" "UA" "48.4647" "35.0462"
output "relay-ua-lviv.macula.io" "Lviv" "UA" "49.8397" "24.0297"
output "relay-ua-zaporizhzhia.macula.io" "Zaporizhzhia" "UA" "47.8388" "35.1396"
output "relay-ua-chernihiv.macula.io" "Chernihiv" "UA" "51.4982" "31.2893"
output "relay-ua-cherkasy.macula.io" "Cherkasy" "UA" "49.4444" "32.0598"
output "relay-ua-poltava.macula.io" "Poltava" "UA" "49.5883" "34.5514"
output "relay-ua-sumy.macula.io" "Sumy" "UA" "50.9077" "34.7981"
output "relay-ua-zhytomyr.macula.io" "Zhytomyr" "UA" "50.2547" "28.6587"
output "relay-ua-rivne.macula.io" "Rivne" "UA" "50.6199" "26.2516"
output "relay-ua-ternopil.macula.io" "Ternopil" "UA" "49.5535" "25.5948"
output "relay-ua-lutsk.macula.io" "Lutsk" "UA" "50.7472" "25.3254"
output "relay-ua-ivano-frankivsk.macula.io" "Ivano-Frankivsk" "UA" "48.9226" "24.7111"
output "relay-ua-uzhhorod.macula.io" "Uzhhorod" "UA" "48.6208" "22.2879"
output "relay-ua-vinnytsia.macula.io" "Vinnytsia" "UA" "49.2331" "28.4682"
output "relay-ua-khmelnytskyi.macula.io" "Khmelnytskyi" "UA" "49.4230" "26.9871"
output "relay-ua-chernivtsi.macula.io" "Chernivtsi" "UA" "48.2921" "25.9358"
output "relay-ua-kropyvnytskyi.macula.io" "Kropyvnytskyi" "UA" "48.5079" "32.2623"
output "relay-ua-mykolaiv.macula.io" "Mykolaiv" "UA" "46.9750" "31.9946"
output "relay-ua-kherson.macula.io" "Kherson" "UA" "46.6354" "32.6169"
output "relay-ua-mariupol.macula.io" "Mariupol" "UA" "47.0958" "37.5494"
output "relay-ua-donetsk.macula.io" "Donetsk" "UA" "48.0159" "37.8029"
output "relay-ua-luhansk.macula.io" "Luhansk" "UA" "48.5740" "39.3078"
output "relay-ua-kramatorsk.macula.io" "Kramatorsk" "UA" "48.7364" "37.5558"
output "relay-ua-melitopol.macula.io" "Melitopol" "UA" "46.8489" "35.3675"
output "relay-ua-berdyansk.macula.io" "Berdyansk" "UA" "46.7656" "36.7982"
output "relay-ua-nikopol.macula.io" "Nikopol" "UA" "47.5715" "34.3935"
output "relay-ua-pavlohrad.macula.io" "Pavlohrad" "UA" "48.5332" "35.8709"
output "relay-ua-bila-tserkva.macula.io" "Bila Tserkva" "UA" "49.7988" "30.1260"
output "relay-ua-konotop.macula.io" "Konotop" "UA" "51.2400" "33.2050"
output "relay-ua-korosten.macula.io" "Korosten" "UA" "50.9519" "28.6352"
output "relay-ua-shepetivka.macula.io" "Shepetivka" "UA" "50.1836" "27.0617"
output "relay-ua-nizhyn.macula.io" "Nizhyn" "UA" "51.0488" "31.8863"
output "relay-ua-slavuta.macula.io" "Slavuta" "UA" "50.3008" "26.8676"
output "relay-ua-irpin.macula.io" "Irpin" "UA" "50.5216" "30.2503"
output "relay-ua-bucha.macula.io" "Bucha" "UA" "50.5437" "30.2131"
output "relay-ua-kremenchuk.macula.io" "Kremenchuk" "UA" "49.0653" "33.4207"
output "relay-ua-severodonetsk.macula.io" "Severodonetsk" "UA" "48.9484" "38.4937"

# ── Poland (15) ──────────────────────────────────────────────────
output "relay-pl-warsaw.macula.io" "Warsaw" "PL" "52.2297" "21.0122"
output "relay-pl-krakow.macula.io" "Krakow" "PL" "50.0647" "19.9450"
output "relay-pl-wroclaw.macula.io" "Wroclaw" "PL" "51.1079" "17.0385"
output "relay-pl-poznan.macula.io" "Poznan" "PL" "52.4064" "16.9252"
output "relay-pl-gdansk.macula.io" "Gdansk" "PL" "54.3520" "18.6466"
output "relay-pl-szczecin.macula.io" "Szczecin" "PL" "53.4285" "14.5528"
output "relay-pl-lublin.macula.io" "Lublin" "PL" "51.2465" "22.5684"
output "relay-pl-katowice.macula.io" "Katowice" "PL" "50.2649" "19.0238"
output "relay-pl-lodz.macula.io" "Lodz" "PL" "51.7592" "19.4560"
output "relay-pl-rzeszow.macula.io" "Rzeszow" "PL" "50.0412" "21.9991"
output "relay-pl-bialystok.macula.io" "Bialystok" "PL" "53.1325" "23.1688"
output "relay-pl-olsztyn.macula.io" "Olsztyn" "PL" "53.7784" "20.4801"
output "relay-pl-torun.macula.io" "Torun" "PL" "53.0138" "18.5984"
output "relay-pl-radom.macula.io" "Radom" "PL" "51.4027" "21.1471"
output "relay-pl-przemysl.macula.io" "Przemysl" "PL" "49.7838" "22.7679"

# ── Baltics (10) ─────────────────────────────────────────────────
output "relay-ee-tallinn.macula.io" "Tallinn" "EE" "59.4370" "24.7536"
output "relay-ee-tartu.macula.io" "Tartu" "EE" "58.3780" "26.7290"
output "relay-lv-riga.macula.io" "Riga" "LV" "56.9496" "24.1052"
output "relay-lv-daugavpils.macula.io" "Daugavpils" "LV" "55.8749" "26.5356"
output "relay-lv-liepaja.macula.io" "Liepaja" "LV" "56.5050" "21.0109"
output "relay-lt-vilnius.macula.io" "Vilnius" "LT" "54.6872" "25.2797"
output "relay-lt-kaunas.macula.io" "Kaunas" "LT" "54.8985" "23.9036"
output "relay-lt-klaipeda.macula.io" "Klaipeda" "LT" "55.7033" "21.1443"
output "relay-lt-siauliai.macula.io" "Siauliai" "LT" "55.9349" "23.3137"
output "relay-lt-panevezys.macula.io" "Panevezys" "LT" "55.7347" "24.3575"

# ── Romania / Moldova (10) ───────────────────────────────────────
output "relay-ro-bucharest.macula.io" "Bucharest" "RO" "44.4268" "26.1025"
output "relay-ro-cluj-napoca.macula.io" "Cluj-Napoca" "RO" "46.7712" "23.6236"
output "relay-ro-timisoara.macula.io" "Timisoara" "RO" "45.7489" "21.2087"
output "relay-ro-iasi.macula.io" "Iasi" "RO" "47.1585" "27.6014"
output "relay-ro-constanta.macula.io" "Constanta" "RO" "44.1598" "28.6348"
output "relay-ro-brasov.macula.io" "Brasov" "RO" "45.6427" "25.5887"
output "relay-ro-craiova.macula.io" "Craiova" "RO" "44.3302" "23.7949"
output "relay-ro-galati.macula.io" "Galati" "RO" "45.4353" "28.0080"
output "relay-md-chisinau.macula.io" "Chisinau" "MD" "47.0105" "28.8638"
output "relay-md-balti.macula.io" "Balti" "MD" "47.7617" "27.9289"

# ── Greece / Balkans (5) ─────────────────────────────────────────
output "relay-gr-athens.macula.io" "Athens" "GR" "37.9838" "23.7275"
output "relay-gr-thessaloniki.macula.io" "Thessaloniki" "GR" "40.6401" "22.9444"
output "relay-rs-belgrade.macula.io" "Belgrade" "RS" "44.7866" "20.4489"
output "relay-bg-sofia.macula.io" "Sofia" "BG" "42.6977" "23.3219"
output "relay-hr-zagreb.macula.io" "Zagreb" "HR" "45.8150" "15.9819"

echo ""
