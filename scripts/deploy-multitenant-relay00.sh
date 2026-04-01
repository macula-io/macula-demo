#!/bin/bash
# Deploy multi-tenant relay identities on relay00 Hetzner box.
#
# Adds virtual relay identities to the existing relay00 process.
# Same port (4433), same container, just more identities in the relay graph.
#
# Also updates Caddy to serve /health and /status for the new hostnames.
#
# Usage: ./scripts/deploy-multitenant-relay00.sh

set -eu

HOST="root@relay00.macula.io"
REMOTE_DIR="/root/macula-realm-compose"

# Virtual relay identities: hostname:city:country:lat:lng
IDENTITIES="relay-nl-amsterdam.macula.io:Amsterdam:NL:52.3676:4.9041,relay-pl-lodz.macula.io:Lodz:PL:51.7592:19.4560"

echo "=== Deploying multi-tenant relay identities to relay00 ==="

# 1. Update Caddyfile to handle new hostnames
echo "[1/3] Updating Caddyfile..."
ssh "${HOST}" "cat > ${REMOTE_DIR}/caddy/Caddyfile.relay << 'CADDYEOF'
# Multi-tenant relay Caddyfile — relay00 + virtual relay identities
# All hostnames proxy to the same relay health port (one process).

relay00.macula.io {
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
        header Content-Type \"application/json\"
        respond \`{\"service\":\"macula-relay\",\"hostname\":\"relay00.macula.io\"}\` 200
    }
}

relay-nl-amsterdam.macula.io {
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
        header Content-Type \"application/json\"
        respond \`{\"service\":\"macula-relay\",\"hostname\":\"relay-nl-amsterdam.macula.io\"}\` 200
    }
}

relay-pl-lodz.macula.io {
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
        header Content-Type \"application/json\"
        respond \`{\"service\":\"macula-relay\",\"hostname\":\"relay-pl-lodz.macula.io\"}\` 200
    }
}
CADDYEOF"

# 2. Add MACULA_RELAY_IDENTITIES to the compose env
echo "[2/3] Adding virtual relay identities..."
ssh "${HOST}" "
    if ! grep -q MACULA_RELAY_IDENTITIES ${REMOTE_DIR}/.env 2>/dev/null; then
        echo 'MACULA_RELAY_IDENTITIES=${IDENTITIES}' >> ${REMOTE_DIR}/.env
    else
        sed -i 's|^MACULA_RELAY_IDENTITIES=.*|MACULA_RELAY_IDENTITIES=${IDENTITIES}|' ${REMOTE_DIR}/.env
    fi
"

# Also need to pass the env var to the relay container
# Check if the compose already has it
ssh "${HOST}" "
    if ! grep -q MACULA_RELAY_IDENTITIES ${REMOTE_DIR}/docker-compose-relay.yml 2>/dev/null; then
        # Add it to the relay service environment section
        sed -i '/MACULA_RELAYS:/a\\      MACULA_RELAY_IDENTITIES: \${MACULA_RELAY_IDENTITIES:-}' ${REMOTE_DIR}/docker-compose-relay.yml
    fi
"

# 3. Recreate containers (Caddy for new certs, relay for new env)
echo "[3/3] Recreating containers..."
ssh "${HOST}" "cd ${REMOTE_DIR} && docker compose -f docker-compose-relay.yml up -d --force-recreate"

echo ""
echo "Waiting for cert issuance + relay startup..."
sleep 15

for fqdn in relay00.macula.io relay-nl-amsterdam.macula.io relay-pl-lodz.macula.io; do
    result=$(curl -sf "https://${fqdn}/status" --max-time 10 2>/dev/null | python3 -c "
import json,sys
d = json.load(sys.stdin)
graph = d.get('topology',{}).get('relay_graph',[])
own = [r['hostname'] for r in graph if r['status']=='online' and r.get('identity',{}).get('hostname')==d.get('hostname')]
print(f'healthy ({len(graph)} relays in graph)')
" 2>/dev/null || echo "not ready (cert may still be issuing)")
    echo "  ${fqdn}: ${result}"
done

echo ""
echo "Done. Virtual relays will appear in the relay graph after the first"
echo "consistency check (~60s). Nodes can connect to any hostname on port 4433."
