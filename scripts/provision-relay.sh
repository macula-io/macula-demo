#!/usr/bin/env bash
#
# Provision a fresh VPS as a Macula relay node.
#
# Usage:
#   ./scripts/provision-relay.sh <ssh-host> [--sshpass <file>]
#
# Example:
#   ./scripts/provision-relay.sh root@relay03.macula.io --sshpass ~/.config/macula/sshpass.txt
#
# What this does:
#   1. Installs Docker + Docker Compose plugin
#   2. Configures firewall (SSH, QUIC/UDP 4433, HTTP 80, HTTPS 443)
#   3. Copies relay/ directory to the remote host
#   4. Prompts you to create .env and docker-config.json from examples
#
# Prerequisites:
#   - SSH access to the target host
#   - DNS A record pointing to the server's IP
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ── Parse args ─────────────────────────────────────────────────────
SSH_HOST=""
SSHPASS_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sshpass)
            SSHPASS_FILE="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            SSH_HOST="$1"
            shift
            ;;
    esac
done

if [[ -z "$SSH_HOST" ]]; then
    echo "Usage: $0 <ssh-host> [--sshpass <file>]" >&2
    exit 1
fi

# ── SSH helper ─────────────────────────────────────────────────────
ssh_cmd() {
    if [[ -n "$SSHPASS_FILE" ]]; then
        sshpass -f "$SSHPASS_FILE" ssh -o StrictHostKeyChecking=no "$SSH_HOST" "$1"
    else
        ssh -o StrictHostKeyChecking=no "$SSH_HOST" "$1"
    fi
}

scp_cmd() {
    if [[ -n "$SSHPASS_FILE" ]]; then
        sshpass -f "$SSHPASS_FILE" scp -o StrictHostKeyChecking=no -r "$1" "$SSH_HOST:$2"
    else
        scp -o StrictHostKeyChecking=no -r "$1" "$SSH_HOST:$2"
    fi
}

echo "=== Provisioning Macula Relay: ${SSH_HOST} ==="

# ── 1. Install Docker ─────────────────────────────────────────────
echo "--- [1/4] Installing Docker ---"
ssh_cmd '
    if command -v docker &>/dev/null; then
        echo "Docker already installed: $(docker --version)"
    else
        apt-get update -qq
        apt-get install -y -qq ca-certificates curl gnupg

        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
          > /etc/apt/sources.list.d/docker.list

        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

        systemctl enable docker
        systemctl start docker
        echo "Docker installed: $(docker --version)"
    fi
'

# ── 2. Firewall ───────────────────────────────────────────────────
echo "--- [2/4] Configuring firewall ---"
ssh_cmd '
    apt-get install -y -qq ufw 2>/dev/null
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    ufw allow 22/tcp >/dev/null    # SSH
    ufw allow 80/tcp >/dev/null    # Caddy HTTP (ACME + health)
    ufw allow 443/tcp >/dev/null   # Caddy HTTPS
    ufw allow 4433/udp >/dev/null  # QUIC relay
    ufw --force enable >/dev/null
    echo "Firewall configured: SSH, HTTP, HTTPS, QUIC"
'

# ── 3. Copy relay config ─────────────────────────────────────────
echo "--- [3/4] Copying relay config ---"
ssh_cmd 'mkdir -p /root/macula-demo'
scp_cmd "${REPO_DIR}/relay" "/root/macula-demo/"
echo "Relay config copied to /root/macula-demo/relay/"

# ── 4. Instructions ──────────────────────────────────────────────
echo "--- [4/4] Next steps ---"
echo ""
echo "  SSH into the host and configure:"
echo ""
echo "    ssh ${SSH_HOST}"
echo "    cd /root/macula-demo/relay"
echo "    cp .env.example .env                        # set RELAY_HOSTNAME, LINODE_DNS_API_TOKEN"
echo "    cp docker-config.json.example docker-config.json  # set ghcr.io auth"
echo ""
echo "  Then deploy:"
echo ""
echo "    ./scripts/deploy-relay.sh ${SSH_HOST}"
echo ""
echo "=== Provisioning complete ==="
