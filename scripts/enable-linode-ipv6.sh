#!/bin/bash
# Enable IPv6 on Linode boxes.
#
# Linode allocates SLAAC IPv6 + optional /64 ranges but doesn't configure
# them in netplan by default. This script writes the netplan config and
# applies it safely with `netplan try` (auto-reverts in 120s on failure).
#
# Usage:
#   ./scripts/enable-linode-ipv6.sh <box-name>
#
# Box names:
#   frankfurt   — box-linode-frankfurt (realm server, SLAAC only)
#   amsterdam   — box-linode-amsterdam (relay box, SLAAC + /64 range)
#
# Prerequisites:
#   - SSH access to the target Linode

set -euo pipefail

BOX="${1:?Usage: $0 <frankfurt|amsterdam>}"

case "${BOX}" in
  frankfurt)
    SSH_HOST="root@172.104.143.73"
    BOX_NAME="box-linode-frankfurt"
    NETPLAN_CONTENT='# Macula realm server — box-linode-frankfurt
# IPv4 via DHCP, IPv6 via static SLAAC address
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      addresses:
        - "2a01:7e01::f03c:94ff:fe22:719e/128"
      routes:
        - to: "::/0"
          via: "fe80::1"
          on-link: true'
    TEST_ADDR="2a01:7e01::f03c:94ff:fe22:719e"
    ;;
  amsterdam)
    SSH_HOST="root@172.235.174.211"
    BOX_NAME="box-linode-amsterdam"
    # SLAAC address + /64 range for relay identities
    # The /64 range (2600:3c0e:e001:ec::/64) needs a route via the SLAAC gateway
    NETPLAN_CONTENT='# Macula relay box — box-linode-amsterdam
# IPv4 via DHCP, IPv6 SLAAC + /64 range for relay identities
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
      addresses:
        - "2600:3c0e::2000:89ff:fe8e:4030/128"
        - "2600:3c0e:e001:ec::1/64"
      routes:
        - to: "::/0"
          via: "fe80::1"
          on-link: true'
    TEST_ADDR="2600:3c0e:e001:ec::1"
    ;;
  *)
    echo "Unknown box: ${BOX}" >&2
    echo "Valid: frankfurt, amsterdam" >&2
    exit 1
    ;;
esac

echo "=== Enable IPv6 on ${BOX_NAME} ==="
echo ""
echo "Current netplan config:"
ssh -o StrictHostKeyChecking=no "${SSH_HOST}" "cat /etc/netplan/*.yaml" 2>/dev/null
echo ""

echo "Will write:"
echo ""
echo "${NETPLAN_CONTENT}"
echo ""

read -p "Apply this config to ${BOX_NAME}? [y/N] " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Writing netplan config..."
ssh -o StrictHostKeyChecking=no "${SSH_HOST}" "cat > /etc/netplan/01-netcfg.yaml << 'NETEOF'
${NETPLAN_CONTENT}
NETEOF"

echo "Applying netplan (auto-reverts in 120s if SSH breaks)..."
ssh -o StrictHostKeyChecking=no "${SSH_HOST}" "netplan try --timeout 120" 2>/dev/null

echo ""
echo "Remote IPv6 addresses:"
ssh -o StrictHostKeyChecking=no "${SSH_HOST}" "ip -6 addr show eth0 scope global" 2>/dev/null

echo ""
echo "Testing from this machine..."
/usr/bin/ping -6 -c 2 -W 3 "${TEST_ADDR}" 2>/dev/null \
  && echo "SUCCESS: ${BOX_NAME} reachable via IPv6" \
  || echo "FAILED: not reachable yet (may need a few seconds)"

echo ""
echo "=== Done ==="
