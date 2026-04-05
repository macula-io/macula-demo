#!/bin/bash
# Generate ~150 relay identities spread evenly across Europe.
# Split between 2 boxes: Nuremberg (western/southern) + Helsinki (eastern/northern).
#
# Usage:
#   ./scripts/generate-europe-150.sh nuremberg   # Western/Southern (75)
#   ./scripts/generate-europe-150.sh helsinki     # Eastern/Northern (75)
#   ./scripts/generate-europe-150.sh all          # Both (150)
#   ./scripts/generate-europe-150.sh count        # Show distribution

set -euo pipefail

BOX="${1:?Usage: $0 nuremberg|helsinki|all|count}"

NUR_PREFIX="2a01:4f8:1c1f:8ab8"
HEL_PREFIX="2a01:4f9:c014:4259"

# Append IPv6 address to each identity line (6th field)
add_ipv6() {
  local prefix="$1"
  local idx=256  # start at ::100
  while IFS= read -r line; do
    local hex
    hex=$(printf '%x' $idx)
    echo "${line}/${prefix}::${hex}"
    idx=$((idx + 1))
  done
}

# ── Nuremberg: Western + Southern Europe (75) ────────────────────
nuremberg() {
cat <<'RELAYS'
relay-gb-london.macula.io/London/GB/51.5074/-0.1278
relay-gb-edinburgh.macula.io/Edinburgh/GB/55.9533/-3.1883
relay-gb-manchester.macula.io/Manchester/GB/53.4808/-2.2426
relay-gb-birmingham.macula.io/Birmingham/GB/52.4862/-1.8904
relay-gb-glasgow.macula.io/Glasgow/GB/55.8642/-4.2518
relay-gb-leeds.macula.io/Leeds/GB/53.8008/-1.5491
relay-gb-bristol.macula.io/Bristol/GB/51.4545/-2.5879
relay-gb-cardiff.macula.io/Cardiff/GB/51.4816/-3.1791
relay-gb-belfast.macula.io/Belfast/GB/54.5973/-5.9301
relay-ie-dublin.macula.io/Dublin/IE/53.3498/-6.2603
relay-ie-cork.macula.io/Cork/IE/51.8985/-8.4756
relay-fr-paris.macula.io/Paris/FR/48.8566/2.3522
relay-fr-lyon.macula.io/Lyon/FR/45.7640/4.8357
relay-fr-marseille.macula.io/Marseille/FR/43.2965/5.3698
relay-fr-toulouse.macula.io/Toulouse/FR/43.6047/1.4442
relay-fr-nice.macula.io/Nice/FR/43.7102/7.2620
relay-fr-nantes.macula.io/Nantes/FR/47.2184/-1.5536
relay-fr-strasbourg.macula.io/Strasbourg/FR/48.5734/7.7521
relay-fr-bordeaux.macula.io/Bordeaux/FR/44.8378/-0.5792
relay-fr-lille.macula.io/Lille/FR/50.6292/3.0573
relay-be-brussels.macula.io/Brussels/BE/50.8503/4.3517
relay-be-antwerp.macula.io/Antwerp/BE/51.2194/4.4025
relay-be-ghent.macula.io/Ghent/BE/51.0543/3.7174
relay-be-liege.macula.io/Liege/BE/50.6292/5.5797
relay-be-charleroi.macula.io/Charleroi/BE/50.4108/4.4446
relay-nl-amsterdam.macula.io/Amsterdam/NL/52.3676/4.9041
relay-nl-rotterdam.macula.io/Rotterdam/NL/51.9244/4.4777
relay-nl-utrecht.macula.io/Utrecht/NL/52.0907/5.1214
relay-nl-eindhoven.macula.io/Eindhoven/NL/51.4416/5.4697
relay-nl-groningen.macula.io/Groningen/NL/53.2194/6.5665
relay-nl-den-haag.macula.io/Den Haag/NL/52.0705/4.3007
relay-lu-luxembourg.macula.io/Luxembourg/LU/49.6117/6.1300
relay-de-berlin.macula.io/Berlin/DE/52.5200/13.4050
relay-de-munich.macula.io/Munich/DE/48.1351/11.5820
relay-de-hamburg.macula.io/Hamburg/DE/53.5511/9.9937
relay-de-frankfurt.macula.io/Frankfurt/DE/50.1109/8.6821
relay-de-cologne.macula.io/Cologne/DE/50.9375/6.9603
relay-de-stuttgart.macula.io/Stuttgart/DE/48.7758/9.1829
relay-de-dusseldorf.macula.io/Dusseldorf/DE/51.2277/6.7735
relay-de-leipzig.macula.io/Leipzig/DE/51.3397/12.3731
relay-de-dresden.macula.io/Dresden/DE/51.0504/13.7373
relay-de-nuremberg.macula.io/Nuremberg/DE/49.4521/11.0767
relay-ch-zurich.macula.io/Zurich/CH/47.3769/8.5417
relay-ch-geneva.macula.io/Geneva/CH/46.2044/6.1432
relay-ch-bern.macula.io/Bern/CH/46.9480/7.4474
relay-at-vienna.macula.io/Vienna/AT/48.2082/16.3738
relay-at-graz.macula.io/Graz/AT/47.0707/15.4395
relay-at-salzburg.macula.io/Salzburg/AT/47.8095/13.0550
relay-es-madrid.macula.io/Madrid/ES/40.4168/-3.7038
relay-es-barcelona.macula.io/Barcelona/ES/41.3851/2.1734
relay-es-valencia.macula.io/Valencia/ES/39.4699/-0.3763
relay-es-seville.macula.io/Seville/ES/37.3891/-5.9845
relay-es-bilbao.macula.io/Bilbao/ES/43.2630/-2.9350
relay-es-malaga.macula.io/Malaga/ES/36.7213/-4.4214
relay-pt-lisbon.macula.io/Lisbon/PT/38.7223/-9.1393
relay-pt-porto.macula.io/Porto/PT/41.1579/-8.6291
relay-it-rome.macula.io/Rome/IT/41.9028/12.4964
relay-it-milan.macula.io/Milan/IT/45.4642/9.1900
relay-it-naples.macula.io/Naples/IT/40.8518/14.2681
relay-it-turin.macula.io/Turin/IT/45.0703/7.6869
relay-it-florence.macula.io/Florence/IT/43.7696/11.2558
relay-it-venice.macula.io/Venice/IT/45.4408/12.3155
relay-it-palermo.macula.io/Palermo/IT/38.1157/13.3615
relay-hr-zagreb.macula.io/Zagreb/HR/45.8150/15.9819
relay-si-ljubljana.macula.io/Ljubljana/SI/46.0569/14.5058
relay-rs-belgrade.macula.io/Belgrade/RS/44.7866/20.4489
relay-ba-sarajevo.macula.io/Sarajevo/BA/43.8563/18.4131
relay-me-podgorica.macula.io/Podgorica/ME/42.4304/19.2594
relay-al-tirana.macula.io/Tirana/AL/41.3275/19.8187
relay-mk-skopje.macula.io/Skopje/MK/41.9973/21.4280
relay-mt-valletta.macula.io/Valletta/MT/35.8989/14.5146
relay-cy-nicosia.macula.io/Nicosia/CY/35.1856/33.3823
relay-is-reykjavik.macula.io/Reykjavik/IS/64.1466/-21.9426
relay-it-bari.macula.io/Bari/IT/41.1171/16.8719
relay-gr-athens.macula.io/Athens/GR/37.9838/23.7275
RELAYS
}

# ── Helsinki: Eastern + Northern Europe (75) ─────────────────────
helsinki() {
cat <<'RELAYS'
relay-fi-helsinki.macula.io/Helsinki/FI/60.1699/24.9384
relay-fi-tampere.macula.io/Tampere/FI/61.4978/23.7610
relay-fi-turku.macula.io/Turku/FI/60.4518/22.2666
relay-fi-oulu.macula.io/Oulu/FI/65.0121/25.4651
relay-se-stockholm.macula.io/Stockholm/SE/59.3293/18.0686
relay-se-gothenburg.macula.io/Gothenburg/SE/57.7089/11.9746
relay-se-malmo.macula.io/Malmo/SE/55.6050/13.0038
relay-se-uppsala.macula.io/Uppsala/SE/59.8586/17.6389
relay-no-oslo.macula.io/Oslo/NO/59.9139/10.7522
relay-no-bergen.macula.io/Bergen/NO/60.3913/5.3221
relay-no-trondheim.macula.io/Trondheim/NO/63.4305/10.3951
relay-dk-copenhagen.macula.io/Copenhagen/DK/55.6761/12.5683
relay-dk-aarhus.macula.io/Aarhus/DK/56.1629/10.2039
relay-ee-tallinn.macula.io/Tallinn/EE/59.4370/24.7536
relay-ee-tartu.macula.io/Tartu/EE/58.3780/26.7290
relay-lv-riga.macula.io/Riga/LV/56.9496/24.1052
relay-lv-daugavpils.macula.io/Daugavpils/LV/55.8749/26.5356
relay-lt-vilnius.macula.io/Vilnius/LT/54.6872/25.2797
relay-lt-kaunas.macula.io/Kaunas/LT/54.8985/23.9036
relay-lt-klaipeda.macula.io/Klaipeda/LT/55.7033/21.1443
relay-pl-warsaw.macula.io/Warsaw/PL/52.2297/21.0122
relay-pl-krakow.macula.io/Krakow/PL/50.0647/19.9450
relay-pl-gdansk.macula.io/Gdansk/PL/54.3520/18.6466
relay-pl-wroclaw.macula.io/Wroclaw/PL/51.1079/17.0385
relay-pl-poznan.macula.io/Poznan/PL/52.4064/16.9252
relay-pl-lodz.macula.io/Lodz/PL/51.7592/19.4560
relay-pl-szczecin.macula.io/Szczecin/PL/53.4285/14.5528
relay-pl-lublin.macula.io/Lublin/PL/51.2465/22.5684
relay-pl-katowice.macula.io/Katowice/PL/50.2649/19.0238
relay-pl-rzeszow.macula.io/Rzeszow/PL/50.0412/21.9991
relay-cz-prague.macula.io/Prague/CZ/50.0755/14.4378
relay-cz-brno.macula.io/Brno/CZ/49.1951/16.6068
relay-sk-bratislava.macula.io/Bratislava/SK/48.1486/17.1077
relay-sk-kosice.macula.io/Kosice/SK/48.7164/21.2611
relay-hu-budapest.macula.io/Budapest/HU/47.4979/19.0402
relay-hu-debrecen.macula.io/Debrecen/HU/47.5316/21.6273
relay-ro-bucharest.macula.io/Bucharest/RO/44.4268/26.1025
relay-ro-cluj.macula.io/Cluj-Napoca/RO/46.7712/23.6236
relay-ro-timisoara.macula.io/Timisoara/RO/45.7489/21.2087
relay-ro-iasi.macula.io/Iasi/RO/47.1585/27.6014
relay-ro-constanta.macula.io/Constanta/RO/44.1598/28.6348
relay-ro-brasov.macula.io/Brasov/RO/45.6427/25.5887
relay-bg-sofia.macula.io/Sofia/BG/42.6977/23.3219
relay-bg-plovdiv.macula.io/Plovdiv/BG/42.1354/24.7453
relay-gr-thessaloniki.macula.io/Thessaloniki/GR/40.6401/22.9444
relay-md-chisinau.macula.io/Chisinau/MD/47.0105/28.8638
relay-ua-kyiv.macula.io/Kyiv/UA/50.4501/30.5234
relay-ua-lviv.macula.io/Lviv/UA/49.8397/24.0297
relay-ua-odessa.macula.io/Odessa/UA/46.4825/30.7233
relay-ua-kharkiv.macula.io/Kharkiv/UA/49.9935/36.2304
relay-ua-dnipro.macula.io/Dnipro/UA/48.4647/35.0462
relay-ua-zaporizhzhia.macula.io/Zaporizhzhia/UA/47.8388/35.1396
relay-ua-vinnytsia.macula.io/Vinnytsia/UA/49.2331/28.4682
relay-ua-poltava.macula.io/Poltava/UA/49.5883/34.5514
relay-ua-chernihiv.macula.io/Chernihiv/UA/51.4982/31.2893
relay-ua-sumy.macula.io/Sumy/UA/50.9077/34.7981
relay-ua-zhytomyr.macula.io/Zhytomyr/UA/50.2547/28.6587
relay-ua-rivne.macula.io/Rivne/UA/50.6199/26.2516
relay-ua-ternopil.macula.io/Ternopil/UA/49.5535/25.5948
relay-ua-cherkasy.macula.io/Cherkasy/UA/49.4444/32.0598
relay-ua-mykolaiv.macula.io/Mykolaiv/UA/46.9750/31.9946
relay-ua-kherson.macula.io/Kherson/UA/46.6354/32.6169
relay-ua-donetsk.macula.io/Donetsk/UA/48.0159/37.8029
relay-ua-luhansk.macula.io/Luhansk/UA/48.5740/39.3078
relay-ua-mariupol.macula.io/Mariupol/UA/47.0958/37.5494
relay-ua-kramatorsk.macula.io/Kramatorsk/UA/48.7364/37.5558
relay-ua-ivano-frankivsk.macula.io/Ivano-Frankivsk/UA/48.9226/24.7111
relay-ua-uzhhorod.macula.io/Uzhhorod/UA/48.6208/22.2879
relay-ua-lutsk.macula.io/Lutsk/UA/50.7472/25.3254
relay-ua-khmelnytskyi.macula.io/Khmelnytskyi/UA/49.4230/26.9871
relay-ua-chernivtsi.macula.io/Chernivtsi/UA/48.2921/25.9358
relay-ua-kropyvnytskyi.macula.io/Kropyvnytskyi/UA/48.5079/32.2623
relay-ua-nikopol.macula.io/Nikopol/UA/47.5715/34.3935
relay-ua-melitopol.macula.io/Melitopol/UA/46.8489/35.3675
relay-ua-severodonetsk.macula.io/Severodonetsk/UA/48.9484/38.4937
RELAYS
}

case "${BOX}" in
  nuremberg)
    nuremberg | add_ipv6 "$NUR_PREFIX" | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  helsinki)
    helsinki | add_ipv6 "$HEL_PREFIX" | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  all)
    { nuremberg | add_ipv6 "$NUR_PREFIX"; helsinki | add_ipv6 "$HEL_PREFIX"; } | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  count)
    echo "Nuremberg: $(nuremberg | wc -l) relays (prefix: ${NUR_PREFIX})"
    nuremberg | awk -F'/' '{print $3}' | sort | uniq -c | sort -rn | sed 's/^/  /'
    echo ""
    echo "Helsinki:  $(helsinki | wc -l) relays (prefix: ${HEL_PREFIX})"
    helsinki | awk -F'/' '{print $3}' | sort | uniq -c | sort -rn | sed 's/^/  /'
    echo ""
    echo "Total: $(( $(nuremberg | wc -l) + $(helsinki | wc -l) ))"
    ;;
  *)
    echo "Usage: $0 nuremberg|helsinki|all|count"
    exit 1
    ;;
esac
