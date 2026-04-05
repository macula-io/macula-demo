#!/bin/bash
# Generate ~50 relay identities spread evenly across Europe.
# Split between 2 boxes: Nuremberg (western) + Helsinki (eastern).
#
# Usage:
#   ./scripts/generate-europe-50.sh nuremberg   # Western/Southern (25)
#   ./scripts/generate-europe-50.sh helsinki     # Eastern/Northern (25)
#   ./scripts/generate-europe-50.sh all          # Both (for reference)

set -euo pipefail

BOX="${1:?Usage: $0 nuremberg|helsinki|all}"

# ── Nuremberg: Western + Southern Europe (25) ────────────────────
nuremberg() {
cat <<'RELAYS'
relay-gb-london.macula.io/London/GB/51.5074/-0.1278
relay-gb-edinburgh.macula.io/Edinburgh/GB/55.9533/-3.1883
relay-gb-manchester.macula.io/Manchester/GB/53.4808/-2.2426
relay-ie-dublin.macula.io/Dublin/IE/53.3498/-6.2603
relay-fr-paris.macula.io/Paris/FR/48.8566/2.3522
relay-fr-lyon.macula.io/Lyon/FR/45.7640/4.8357
relay-fr-marseille.macula.io/Marseille/FR/43.2965/5.3698
relay-be-brussels.macula.io/Brussels/BE/50.8503/4.3517
relay-nl-amsterdam.macula.io/Amsterdam/NL/52.3676/4.9041
relay-nl-rotterdam.macula.io/Rotterdam/NL/51.9244/4.4777
relay-lu-luxembourg.macula.io/Luxembourg/LU/49.6117/6.1300
relay-de-berlin.macula.io/Berlin/DE/52.5200/13.4050
relay-de-munich.macula.io/Munich/DE/48.1351/11.5820
relay-de-hamburg.macula.io/Hamburg/DE/53.5511/9.9937
relay-ch-zurich.macula.io/Zurich/CH/47.3769/8.5417
relay-ch-geneva.macula.io/Geneva/CH/46.2044/6.1432
relay-at-vienna.macula.io/Vienna/AT/48.2082/16.3738
relay-es-madrid.macula.io/Madrid/ES/40.4168/-3.7038
relay-es-barcelona.macula.io/Barcelona/ES/41.3851/2.1734
relay-pt-lisbon.macula.io/Lisbon/PT/38.7223/-9.1393
relay-it-rome.macula.io/Rome/IT/41.9028/12.4964
relay-it-milan.macula.io/Milan/IT/45.4642/9.1900
relay-it-naples.macula.io/Naples/IT/40.8518/14.2681
relay-hr-zagreb.macula.io/Zagreb/HR/45.8150/15.9819
relay-rs-belgrade.macula.io/Belgrade/RS/44.7866/20.4489
RELAYS
}

# ── Helsinki: Eastern + Northern Europe (25) ─────────────────────
helsinki() {
cat <<'RELAYS'
relay-fi-helsinki.macula.io/Helsinki/FI/60.1699/24.9384
relay-se-stockholm.macula.io/Stockholm/SE/59.3293/18.0686
relay-se-gothenburg.macula.io/Gothenburg/SE/57.7089/11.9746
relay-no-oslo.macula.io/Oslo/NO/59.9139/10.7522
relay-dk-copenhagen.macula.io/Copenhagen/DK/55.6761/12.5683
relay-ee-tallinn.macula.io/Tallinn/EE/59.4370/24.7536
relay-lv-riga.macula.io/Riga/LV/56.9496/24.1052
relay-lt-vilnius.macula.io/Vilnius/LT/54.6872/25.2797
relay-pl-warsaw.macula.io/Warsaw/PL/52.2297/21.0122
relay-pl-krakow.macula.io/Krakow/PL/50.0647/19.9450
relay-pl-gdansk.macula.io/Gdansk/PL/54.3520/18.6466
relay-cz-prague.macula.io/Prague/CZ/50.0755/14.4378
relay-sk-bratislava.macula.io/Bratislava/SK/48.1486/17.1077
relay-hu-budapest.macula.io/Budapest/HU/47.4979/19.0402
relay-ro-bucharest.macula.io/Bucharest/RO/44.4268/26.1025
relay-ro-cluj.macula.io/Cluj-Napoca/RO/46.7712/23.6236
relay-bg-sofia.macula.io/Sofia/BG/42.6977/23.3219
relay-gr-athens.macula.io/Athens/GR/37.9838/23.7275
relay-ua-kyiv.macula.io/Kyiv/UA/50.4501/30.5234
relay-ua-lviv.macula.io/Lviv/UA/49.8397/24.0297
relay-ua-odessa.macula.io/Odessa/UA/46.4825/30.7233
relay-ua-kharkiv.macula.io/Kharkiv/UA/49.9935/36.2304
relay-ua-dnipro.macula.io/Dnipro/UA/48.4647/35.0462
relay-md-chisinau.macula.io/Chisinau/MD/47.0105/28.8638
relay-ua-zaporizhzhia.macula.io/Zaporizhzhia/UA/47.8388/35.1396
RELAYS
}

case "${BOX}" in
  nuremberg)
    nuremberg | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  helsinki)
    helsinki | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  all)
    { nuremberg; helsinki; } | tr '\n' ',' | sed 's/,$/\n/'
    ;;
  count)
    echo "Nuremberg: $(nuremberg | wc -l)"
    echo "Helsinki:  $(helsinki | wc -l)"
    echo "Total:     $(( $(nuremberg | wc -l) + $(helsinki | wc -l) ))"
    ;;
  *)
    echo "Usage: $0 nuremberg|helsinki|all|count"
    exit 1
    ;;
esac
