#!/bin/bash
# Deploy multi-tenant relay identities to all 3 physical boxes.
#
# Each box runs ONE relay process on port 4433 with N virtual identities.
# Caddy handles per-hostname TLS certs. All relays peer with each other.
#
# Usage: ./scripts/deploy-multitenant-all.sh
#
# Prerequisites:
#   - DNS A records already created (setup-relay-dns.sh)
#   - LINODE_DNS_API_TOKEN env var set (for Caddy DNS-01)

set -eu

# ── Identity definitions ───────────────────────────────────────────
# Format: hostname:city:country:lat:lng

HETZNER_NUREMBERG_IDENTITIES="relay-de-nuremberg.macula.io:Nuremberg:DE:49.4527:11.0783,relay-de-berlin.macula.io:Berlin:DE:52.5200:13.4050,relay-nl-amsterdam.macula.io:Amsterdam:NL:52.3676:4.9041,relay-be-brussels.macula.io:Brussels:BE:50.8503:4.3517,relay-be-antwerp.macula.io:Antwerp:BE:51.2194:4.4025,relay-ch-zurich.macula.io:Zurich:CH:47.3769:8.5417,relay-at-vienna.macula.io:Vienna:AT:48.2082:16.3738,relay-cz-prague.macula.io:Prague:CZ:50.0755:14.4378,relay-hu-budapest.macula.io:Budapest:HU:47.4979:19.0402"

HETZNER_HELSINKI_IDENTITIES="relay-fi-helsinki.macula.io:Helsinki:FI:60.1699:24.9384,relay-se-stockholm.macula.io:Stockholm:SE:59.3293:18.0686,relay-no-oslo.macula.io:Oslo:NO:59.9139:10.7522,relay-dk-copenhagen.macula.io:Copenhagen:DK:55.6761:12.5683,relay-ee-tallinn.macula.io:Tallinn:EE:59.4370:24.7536,relay-lv-riga.macula.io:Riga:LV:56.9496:24.1052,relay-lt-vilnius.macula.io:Vilnius:LT:54.6872:25.2797,relay-pl-warsaw.macula.io:Warsaw:PL:52.2297:21.0122"

LINODE_FRANKFURT_IDENTITIES="relay-fr-paris.macula.io:Paris:FR:48.8566:2.3522,relay-uk-london.macula.io:London:UK:51.5074:-0.1278,relay-ie-dublin.macula.io:Dublin:IE:53.3498:-6.2603,relay-es-madrid.macula.io:Madrid:ES:40.4168:-3.7038,relay-es-barcelona.macula.io:Barcelona:ES:41.3874:2.1686,relay-pt-lisbon.macula.io:Lisbon:PT:38.7223:-9.1393,relay-it-rome.macula.io:Rome:IT:41.9028:12.4964,relay-it-milan.macula.io:Milan:IT:45.4642:9.1900"

# All relay URLs for MACULA_RELAYS (every relay peers with all others)
ALL_RELAY_URLS="https://relay-de-nuremberg.macula.io:4433,https://relay-de-berlin.macula.io:4433,https://relay-nl-amsterdam.macula.io:4433,https://relay-be-brussels.macula.io:4433,https://relay-be-antwerp.macula.io:4433,https://relay-ch-zurich.macula.io:4433,https://relay-at-vienna.macula.io:4433,https://relay-cz-prague.macula.io:4433,https://relay-hu-budapest.macula.io:4433,https://relay-fi-helsinki.macula.io:4433,https://relay-se-stockholm.macula.io:4433,https://relay-no-oslo.macula.io:4433,https://relay-dk-copenhagen.macula.io:4433,https://relay-ee-tallinn.macula.io:4433,https://relay-lv-riga.macula.io:4433,https://relay-lt-vilnius.macula.io:4433,https://relay-pl-warsaw.macula.io:4433,https://relay-fr-paris.macula.io:4433,https://relay-uk-london.macula.io:4433,https://relay-ie-dublin.macula.io:4433,https://relay-es-madrid.macula.io:4433,https://relay-es-barcelona.macula.io:4433,https://relay-pt-lisbon.macula.io:4433,https://relay-it-rome.macula.io:4433,https://relay-it-milan.macula.io:4433"

# ── Helper: generate Caddyfile ─────────────────────────────────────
generate_caddyfile() {
    local identities_csv="$1"
    local primary_hostname="$2"

    # Always include the primary (relay0X.macula.io) hostname
    local all_hostnames="${primary_hostname}"
    IFS=',' read -ra ENTRIES <<< "${identities_csv}"
    for entry in "${ENTRIES[@]}"; do
        local hostname=$(echo "$entry" | cut -d: -f1)
        all_hostnames="${all_hostnames} ${hostname}"
    done

    # Generate Caddyfile with a block per hostname
    echo "# Multi-tenant relay Caddyfile — auto-generated"
    echo "# Primary: ${primary_hostname}"
    echo "# Virtual identities: ${#ENTRIES[@]}"
    echo ""

    for hostname in ${all_hostnames}; do
        cat <<BLOCK
${hostname} {
    tls {
        dns linode {env.LINODE_DNS_API_TOKEN}
        key_type rsa2048
    }
    handle /health {
        reverse_proxy relay:8080
    }
    handle /status {
        reverse_proxy relay:8080
    }
    handle {
        header Content-Type "application/json"
        respond \`{"service":"macula-relay","hostname":"${hostname}"}\` 200
    }
}

BLOCK
    done
}

# ── Deploy to a box ────────────────────────────────────────────────
deploy_box() {
    local box_name="$1"
    local ssh_host="$2"
    local primary_hostname="$3"
    local identities="$4"
    local remote_dir="$5"

    echo ""
    echo "=== ${box_name} (${ssh_host}) ==="

    # Generate and upload Caddyfile
    echo "[1/3] Generating Caddyfile..."
    generate_caddyfile "${identities}" "${primary_hostname}" > /tmp/Caddyfile.relay
    scp /tmp/Caddyfile.relay "${ssh_host}:${remote_dir}/caddy/Caddyfile.relay"

    # Update .env with identities and relay URLs
    echo "[2/3] Updating environment..."
    ssh "${ssh_host}" "
        cd ${remote_dir}

        # Set or update MACULA_RELAY_IDENTITIES
        if grep -q '^MACULA_RELAY_IDENTITIES=' .env 2>/dev/null; then
            sed -i 's|^MACULA_RELAY_IDENTITIES=.*|MACULA_RELAY_IDENTITIES=${identities}|' .env
        else
            echo 'MACULA_RELAY_IDENTITIES=${identities}' >> .env
        fi

        # Set or update MACULA_RELAYS
        if grep -q '^MACULA_RELAYS=' .env 2>/dev/null; then
            sed -i 's|^MACULA_RELAYS=.*|MACULA_RELAYS=${ALL_RELAY_URLS}|' .env
        else
            echo 'MACULA_RELAYS=${ALL_RELAY_URLS}' >> .env
        fi

        # Ensure MACULA_RELAY_IDENTITIES is passed to relay container
        if ! grep -q MACULA_RELAY_IDENTITIES docker-compose-relay.yml 2>/dev/null; then
            sed -i '/MACULA_RELAYS:/a\\      MACULA_RELAY_IDENTITIES: \${MACULA_RELAY_IDENTITIES:-}' docker-compose-relay.yml
        fi
    "

    # Recreate containers
    echo "[3/3] Recreating containers..."
    ssh "${ssh_host}" "cd ${remote_dir} && docker compose -f docker-compose-relay.yml up -d --force-recreate --build"

    echo "[${box_name}] Done"
}

# ── Main ───────────────────────────────────────────────────────────

echo "=== Deploying multi-tenant relays to all boxes ==="

deploy_box "Hetzner Nuremberg" \
    "root@relay00.macula.io" \
    "relay00.macula.io" \
    "${HETZNER_NUREMBERG_IDENTITIES}" \
    "/root/macula-realm-compose"

deploy_box "Hetzner Helsinki" \
    "root@relay01.macula.io" \
    "relay01.macula.io" \
    "${HETZNER_HELSINKI_IDENTITIES}" \
    "/root/macula-realm-compose"

# Linode is special — relay02 runs in the realm compose, not standalone relay compose.
# We need to update the realm compose's relay service instead.
echo ""
echo "=== Linode Frankfurt (relay02 in realm compose) ==="
echo "[1/3] Generating Caddyfile..."
# The Linode box uses the realm Caddy (wildcard cert *.macula.io), so no per-hostname certs needed.
# But relay02 needs MACULA_RELAY_IDENTITIES in its container env.

echo "[2/3] Updating relay02 environment..."
ssh root@macula.io "
    # Add MACULA_RELAY_IDENTITIES to relay02's env in the realm compose
    REALM_DIR=\$(find / -name 'docker-compose.yml' -path '*/macula-realm*' 2>/dev/null | head -1 | xargs dirname)
    if [ -z \"\$REALM_DIR\" ]; then
        echo 'ERROR: Could not find realm compose directory'
        exit 1
    fi
    echo \"Found realm compose at: \$REALM_DIR\"

    # Update .env
    if grep -q '^MACULA_RELAY_IDENTITIES=' \$REALM_DIR/.env 2>/dev/null; then
        sed -i 's|^MACULA_RELAY_IDENTITIES=.*|MACULA_RELAY_IDENTITIES=${LINODE_FRANKFURT_IDENTITIES}|' \$REALM_DIR/.env
    else
        echo 'MACULA_RELAY_IDENTITIES=${LINODE_FRANKFURT_IDENTITIES}' >> \$REALM_DIR/.env
    fi

    if grep -q '^MACULA_RELAYS=' \$REALM_DIR/.env 2>/dev/null; then
        sed -i 's|^MACULA_RELAYS=.*|MACULA_RELAYS=${ALL_RELAY_URLS}|' \$REALM_DIR/.env
    else
        echo 'MACULA_RELAYS=${ALL_RELAY_URLS}' >> \$REALM_DIR/.env
    fi
"

echo "[3/3] Stopping relay04-06 and restarting relay02..."
ssh root@macula.io "
    # Stop old co-located relays
    cd /root/macula-realm-compose 2>/dev/null && \
        docker compose -f docker-compose.colocated.yml down 2>/dev/null || true

    # Find and restart relay02 in the realm compose
    REALM_DIR=\$(find / -name 'docker-compose.yml' -path '*/macula-realm*' 2>/dev/null | head -1 | xargs dirname)
    cd \$REALM_DIR && docker compose up -d --force-recreate relay 2>/dev/null || \
        echo 'NOTE: May need manual restart of relay02 in realm compose'
"
echo "[Linode] Done"

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Waiting 30s for cert issuance + relay startup..."
sleep 30

echo ""
echo "=== Verification ==="
for fqdn in relay-de-nuremberg relay-fi-helsinki relay-fr-paris relay-nl-amsterdam relay-uk-london relay-se-stockholm; do
    result=$(curl -sf "https://${fqdn}.macula.io/status" --max-time 10 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
print('OK')
" 2>/dev/null || echo "not ready")
    echo "  ${fqdn}.macula.io: ${result}"
done

echo ""
echo "Full relay graph will converge in ~60s."
echo "Check: https://macula.io/topology"
