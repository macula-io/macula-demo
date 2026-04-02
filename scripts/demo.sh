#!/usr/bin/env bash
#
# Relay Mesh Demo — interactive menu for live demos
#
# Usage: ./scripts/demo.sh
#
# The mesh consists of:
# - 3 physical relay boxes hosting 167 virtual relay cities
# - 4 beam nodes running hecate-daemon + 350 stub identities
# - macula.io realm (topology, appstore, etc.)

set -euo pipefail

# ── Physical relay boxes ───────────────────────────────────────────
# Each box runs one macula-relay container with N multi-tenant identities.
RELAY_NAMES=(relay00 relay01 relay02)
RELAY_SSH_HOSTS=(relay00.macula.io relay01.macula.io macula.io)
RELAY_SSH_USER=root
RELAY_COMPOSE_DIRS=(/root/macula-relay /root/macula-relay /root/macula-demo/relay)
RELAY_CONTAINERS=(macula-relay macula-relay macula-relay)
RELAY_CITIES=(100 30 37)
RELAY_LOCATIONS=("Nuremberg, DE" "Helsinki, FI" "Linode, US")

# ── Beam cluster nodes ─────────────────────────────────────────────
NODES=(beam00 beam01 beam02 beam03)
NODE_SSH_USER=rl
NODE_STUBS=(50 100 100 100)

# ── Colors ──────────────────────────────────────────────────────────
R='\033[0;31m'    G='\033[0;32m'    B='\033[0;34m'
C='\033[0;36m'    Y='\033[0;33m'    W='\033[1;37m'
D='\033[0;90m'    N='\033[0m'       BLD='\033[1m'

# ── Helpers ─────────────────────────────────────────────────────────
is_relay_running() {
  local idx=$1
  local host="${RELAY_SSH_HOSTS[$idx]}"
  local container="${RELAY_CONTAINERS[$idx]}"
  local running
  running=$(ssh -o ConnectTimeout=3 "${RELAY_SSH_USER}@${host}" \
    "docker inspect ${container} --format '{{.State.Running}}'" 2>/dev/null || echo "false")
  [[ "$running" == "true" ]]
}

is_node_running() {
  local node="$1"
  local running
  running=$(ssh -o ConnectTimeout=3 "${NODE_SSH_USER}@${node}.lab" \
    "docker ps -q --filter name=hecate-daemon --filter status=running | head -1" 2>/dev/null || echo "")
  [[ -n "$running" ]]
}

count_node_containers() {
  local node="$1"
  ssh -o ConnectTimeout=3 "${NODE_SSH_USER}@${node}.lab" \
    "docker ps -q --filter name=hecate --filter status=running | wc -l" 2>/dev/null || echo "0"
}

json_field() {
  python3 -c "import sys,json; d=json.load(sys.stdin); print($1)" 2>/dev/null || echo "$2"
}

# ── Topology ────────────────────────────────────────────────────────
show_topology() {
  echo -e "\n${W}━━━ RELAY MESH TOPOLOGY ━━━${N}\n"
  echo -e "  ${D}3 physical relay boxes, 167 virtual relay cities${N}"
  echo -e "  ${D}4 beam nodes, ~350 stub identities${N}\n"

  local total_nodes=0 total_topics=0

  for i in "${!RELAY_NAMES[@]}"; do
    local name="${RELAY_NAMES[$i]}"
    local host="${RELAY_SSH_HOSTS[$i]}"
    local loc="${RELAY_LOCATIONS[$i]}"
    local cities="${RELAY_CITIES[$i]}"

    # Fetch /status from the relay's public hostname
    local status_host="${name}.macula.io"
    local json
    json=$(curl -s --connect-timeout 3 "https://${status_host}/status" 2>/dev/null) || json=""

    if [[ -z "$json" ]]; then
      echo -e "  ${R}●${N} ${W}${name}${N}  ${D}${loc}${N}  ${R}OFFLINE${N}  ${D}(${cities} cities)${N}"
      continue
    fi

    local nodes uptime self_count local_t peers_ok
    nodes=$(echo "$json" | json_field "d['topology']['connected_nodes']" "0")
    self_count=$(echo "$json" | json_field "len(d['topology'].get('self_relays',[]))" "0")
    local_t=$(echo "$json" | json_field "len(d['topology']['local_topics'])" "0")
    peers_ok=$(echo "$json" | json_field "sum(1 for p in d['topology']['peers'] if p['connected'])" "0")
    uptime=$(echo "$json" | json_field \
      "s=d['uptime_seconds']; f'{s//3600}h{(s%3600)//60}m' if s>=3600 else f'{s//60}m{s%60}s'" "?")

    total_nodes=$((total_nodes + nodes))
    total_topics=$((total_topics + local_t))

    echo -e "  ${G}●${N} ${W}${name}${N}  ${D}${loc}${N}  ${G}ONLINE${N}"
    echo -e "    ${C}cities:${N} ${self_count}  ${C}nodes:${N} ${nodes}  ${C}peers:${N} ${peers_ok}  ${C}topics:${N} ${local_t}  ${C}up:${N} ${uptime}"
  done

  echo ""
  echo -e "  ${W}━━━ BEAM CLUSTER ━━━${N}\n"

  for i in "${!NODES[@]}"; do
    local node="${NODES[$i]}"
    local stubs="${NODE_STUBS[$i]}"
    local containers
    containers=$(count_node_containers "$node")

    if [[ "$containers" -gt 0 ]]; then
      echo -e "  ${G}●${N} ${W}${node}.lab${N}  ${G}${containers} container(s)${N}  ${D}(~${stubs} stubs)${N}"
    else
      echo -e "  ${R}●${N} ${W}${node}.lab${N}  ${R}DOWN${N}  ${D}(~${stubs} stubs)${N}"
    fi
  done

  echo ""
  echo -e "  ${BLD}Total:${N} ${total_nodes} mesh nodes, ${total_topics} topics"
  echo ""
}

# ── Relay control ───────────────────────────────────────────────────
stop_relay() {
  local idx=$1
  local host="${RELAY_SSH_HOSTS[$idx]}"
  local container="${RELAY_CONTAINERS[$idx]}"
  local cities="${RELAY_CITIES[$idx]}"
  echo -e "  ${Y}⏸${N}  Stopping ${W}${RELAY_NAMES[$idx]}${N} (${cities} virtual cities)..."
  ssh "${RELAY_SSH_USER}@${host}" "docker stop ${container}" >/dev/null 2>&1
  echo -e "  ${R}●${N}  ${RELAY_NAMES[$idx]} is ${R}DOWN${N} — ${cities} cities offline, nodes will failover"
}

start_relay() {
  local idx=$1
  local host="${RELAY_SSH_HOSTS[$idx]}"
  local container="${RELAY_CONTAINERS[$idx]}"
  echo -e "  ${Y}▶${N}  Starting ${W}${RELAY_NAMES[$idx]}${N}..."
  ssh "${RELAY_SSH_USER}@${host}" "docker start ${container}" >/dev/null 2>&1
  echo -e "  ${G}●${N}  ${RELAY_NAMES[$idx]} is ${G}UP${N} — peering + identity init in ~5s"
}

stop_node() {
  local node="$1"
  echo -e "  ${Y}⏸${N}  Stopping all hecate containers on ${W}${node}${N}..."
  ssh "${NODE_SSH_USER}@${node}.lab" "docker stop \$(docker ps -q --filter name=hecate)" >/dev/null 2>&1
  echo -e "  ${R}●${N}  ${node} is ${R}DOWN${N}"
}

start_node() {
  local node="$1"
  echo -e "  ${Y}▶${N}  Starting all hecate containers on ${W}${node}${N}..."
  ssh "${NODE_SSH_USER}@${node}.lab" "docker start \$(docker ps -aq --filter name=hecate)" >/dev/null 2>&1
  echo -e "  ${G}●${N}  ${node} is ${G}UP${N} — connecting in ~5s"
}

# ── Menu: pick relay ────────────────────────────────────────────────
pick_relay() {
  local action="$1"
  echo ""
  for i in "${!RELAY_NAMES[@]}"; do
    local status_icon
    if is_relay_running "$i"; then
      status_icon="${G}●${N}"
    else
      status_icon="${R}●${N}"
    fi
    echo -e "  ${W}$((i+1))${N}  ${status_icon} ${RELAY_NAMES[$i]}  ${D}${RELAY_LOCATIONS[$i]} (${RELAY_CITIES[$i]} cities)${N}"
  done
  echo -e "  ${D}0  back${N}"
  echo ""
  read -rp "  > " choice
  if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#RELAY_NAMES[@]} )); then
    $action $((choice - 1))
  fi
}

# ── Menu: pick node ─────────────────────────────────────────────────
pick_node() {
  local action="$1"
  echo ""
  for i in "${!NODES[@]}"; do
    local node="${NODES[$i]}"
    local status_icon
    if is_node_running "$node"; then
      status_icon="${G}●${N}"
    else
      status_icon="${R}●${N}"
    fi
    echo -e "  ${W}$((i+1))${N}  ${status_icon} ${node}  ${D}(~${NODE_STUBS[$i]} stubs)${N}"
  done
  echo -e "  ${D}0  back${N}"
  echo ""
  read -rp "  > " choice
  if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#NODES[@]} )); then
    $action "${NODES[$((choice - 1))]}"
  fi
}

# ── Chaos mode ──────────────────────────────────────────────────────
chaos_loop() {
  local interval="$1"
  local all_targets=("${RELAY_NAMES[@]}" "${NODES[@]}")

  echo -e "\n${R}━━━ CHAOS MODE ━━━${N}  ${D}(interval: ${interval}s, Ctrl+C to stop)${N}\n"

  while true; do
    sleep "$interval"
    local target_idx=$((RANDOM % ${#all_targets[@]}))
    local target="${all_targets[$target_idx]}"
    local ts
    ts=$(date '+%H:%M:%S')

    if [[ "$target" == relay* ]]; then
      local idx
      for i in "${!RELAY_NAMES[@]}"; do [[ "${RELAY_NAMES[$i]}" == "$target" ]] && idx=$i; done
      if is_relay_running "$idx"; then
        local running_count=0
        for j in "${!RELAY_NAMES[@]}"; do is_relay_running "$j" && running_count=$((running_count + 1)); done
        if [[ "$running_count" -le 1 ]]; then
          echo -e "  ${D}${ts}${N}  ${Y}skip${N} ${target} — last relay standing"
          continue
        fi
        echo -e "  ${D}${ts}${N}  ${R}kill${N} ${W}${target}${N} (${RELAY_CITIES[$idx]} cities go dark)"
        stop_relay "$idx"
      else
        echo -e "  ${D}${ts}${N}  ${G}heal${N} ${W}${target}${N}"
        start_relay "$idx"
      fi
    elif [[ "$target" == beam* ]]; then
      if is_node_running "$target"; then
        local running_count=0
        for node in "${NODES[@]}"; do is_node_running "$node" && running_count=$((running_count + 1)); done
        if [[ "$running_count" -le 1 ]]; then
          echo -e "  ${D}${ts}${N}  ${Y}skip${N} ${target} — last node standing"
          continue
        fi
        echo -e "  ${D}${ts}${N}  ${R}kill${N} ${W}${target}${N}"
        stop_node "$target"
      else
        echo -e "  ${D}${ts}${N}  ${G}heal${N} ${W}${target}${N}"
        start_node "$target"
      fi
    fi
  done
}

start_chaos() {
  echo ""
  echo -e "  ${W}Chaos interval (seconds):${N}"
  echo -e "  ${W}1${N}  5s   ${D}(aggressive)${N}"
  echo -e "  ${W}2${N}  10s  ${D}(moderate)${N}"
  echo -e "  ${W}3${N}  20s  ${D}(gentle)${N}"
  echo -e "  ${D}0  back${N}"
  echo ""
  read -rp "  > " choice
  local interval
  case "$choice" in
    1) interval=5 ;; 2) interval=10 ;; 3) interval=20 ;;
    0|"") return ;; *) return ;;
  esac

  echo -e "\n  ${R}☠${N}  Chaos started — press ${W}Enter${N} to stop\n"

  chaos_loop "$interval" &
  local chaos_pid=$!

  read -r
  kill "$chaos_pid" 2>/dev/null
  wait "$chaos_pid" 2>/dev/null
  echo -e "  ${G}✓${N}  Chaos stopped"
}

heal_all() {
  echo -e "\n${G}━━━ HEALING ALL COMPONENTS ━━━${N}\n"
  for i in "${!RELAY_NAMES[@]}"; do
    if ! is_relay_running "$i"; then
      start_relay "$i"
    fi
  done
  for node in "${NODES[@]}"; do
    if ! is_node_running "$node"; then
      start_node "$node"
    fi
  done
  echo -e "\n  ${G}✓${N}  All components started"
}

# ── Pull latest images ──────────────────────────────────────────────
pull_all() {
  echo -e "\n${C}━━━ PULLING LATEST IMAGES ━━━${N}\n"
  for i in "${!RELAY_NAMES[@]}"; do
    local host="${RELAY_SSH_HOSTS[$i]}"
    echo -e "  ${C}↓${N}  ${W}${RELAY_NAMES[$i]}${N} — pulling + restarting..."
    ssh "${RELAY_SSH_USER}@${host}" \
      "docker pull ghcr.io/macula-io/macula-relay:latest && docker restart ${RELAY_CONTAINERS[$i]}" >/dev/null 2>&1 \
      && echo -e "  ${G}✓${N}  ${RELAY_NAMES[$i]} updated" \
      || echo -e "  ${R}✗${N}  ${RELAY_NAMES[$i]} failed"
  done
  for node in "${NODES[@]}"; do
    echo -e "  ${C}↓${N}  ${W}${node}${N} — pulling + restarting daemon..."
    ssh "${NODE_SSH_USER}@${node}.lab" \
      "docker pull ghcr.io/hecate-social/hecate-daemon:main && docker restart hecate-daemon" >/dev/null 2>&1 \
      && echo -e "  ${G}✓${N}  ${node} updated" \
      || echo -e "  ${R}✗${N}  ${node} failed"
  done
  echo -e "\n  ${G}✓${N}  Pull complete — allow ~10s for startup"
}

# ── Main menu ───────────────────────────────────────────────────────
cleanup() {
  echo ""
  exit 0
}
trap cleanup INT

main_menu() {
  while true; do
    echo -e "\n${W}━━━ MACULA RELAY MESH DEMO ━━━${N}"
    echo -e "${D}  167 relay cities · 350 stub nodes · 3 physical boxes${N}\n"
    echo -e "  ${W}1${N}  Show topology"
    echo -e "  ${W}2${N}  Stop a relay"
    echo -e "  ${W}3${N}  Start a relay"
    echo -e "  ${W}4${N}  Stop a node"
    echo -e "  ${W}5${N}  Start a node"
    echo -e "  ${R}6${N}  ${R}Chaos mode${N}  ${D}(randomly kill/heal components)${N}"
    echo -e "  ${G}7${N}  ${G}Heal all${N}  ${D}(start everything)${N}"
    echo -e "  ${C}8${N}  ${C}Pull latest${N}  ${D}(docker pull + restart all)${N}"
    echo -e "  ${D}q  quit${N}"
    echo ""
    read -rp "  > " choice
    case "$choice" in
      1) show_topology ;;
      2) pick_relay stop_relay ;;
      3) pick_relay start_relay ;;
      4) pick_node stop_node ;;
      5) pick_node start_node ;;
      6) start_chaos ;;
      7) heal_all ;;
      8) pull_all ;;
      q|Q) cleanup ;;
      "") ;;
      *) echo -e "  ${R}?${N}" ;;
    esac
  done
}

main_menu
