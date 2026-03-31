#!/usr/bin/env bash
#
# Relay Mesh Demo — interactive menu for live demos
#
# Usage: ./scripts/demo.sh

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
RELAYS=(relay00.macula.io relay01.macula.io relay02.macula.io relay03.macula.io)
RELAY_SSH_USER=root
RELAY_LOCATIONS=("Nuremberg, DE" "Helsinki, FI" "Linode, US" "Hetzner, DE")
RELAY_CONTAINERS=(macula-relay macula-relay macula-relay macula-relay)
RELAY_SSH_HOSTS=(relay00.macula.io relay01.macula.io macula.io relay03.macula.io)

NODES=(beam00 beam01 beam02 beam03)
NODE_SSH_USER=rl
NODE_CONTAINER=hecate-daemon

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
  running=$(ssh -o ConnectTimeout=3 "${RELAY_SSH_USER}@${host}" "docker inspect ${container} --format '{{.State.Running}}'" 2>/dev/null || echo "false")
  [[ "$running" == "true" ]]
}

is_node_running() {
  local node="$1"
  local running
  running=$(ssh -o ConnectTimeout=3 "${NODE_SSH_USER}@${node}.lab" "docker inspect ${NODE_CONTAINER} --format '{{.State.Running}}'" 2>/dev/null || echo "false")
  [[ "$running" == "true" ]]
}

# ── Topology ────────────────────────────────────────────────────────
show_topology() {
  echo -e "\n${W}━━━ RELAY MESH TOPOLOGY ━━━${N}\n"

  for i in "${!RELAYS[@]}"; do
    local host="${RELAYS[$i]}"
    local loc="${RELAY_LOCATIONS[$i]}"
    local json
    json=$(curl -s --connect-timeout 3 "https://${host}/status" 2>/dev/null) || json=""

    if [[ -z "$json" ]]; then
      echo -e "  ${R}●${N} ${W}${host}${N}  ${D}${loc}${N}  ${R}OFFLINE${N}"
      continue
    fi

    local nodes peers_ok local_t fwd_t uptime names
    nodes=$(echo "$json" | python3 -c "import sys,json; print(json.load(sys.stdin)['topology']['connected_nodes'])" 2>/dev/null || echo 0)
    names=$(echo "$json" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)['topology']['node_names']))" 2>/dev/null || echo "")
    peers_ok=$(echo "$json" | python3 -c "import sys,json; t=json.load(sys.stdin)['topology']; print(sum(1 for p in t['peers'] if p['connected']))" 2>/dev/null || echo 0)
    local_t=$(echo "$json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['topology']['local_topics']))" 2>/dev/null || echo 0)
    fwd_t=$(echo "$json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['topology']['forwarded_topics']))" 2>/dev/null || echo 0)
    uptime=$(echo "$json" | python3 -c "import sys,json; s=json.load(sys.stdin)['uptime_seconds']; print(f'{s//3600}h{(s%3600)//60}m' if s>=3600 else f'{s//60}m{s%60}s')" 2>/dev/null || echo "?")

    local peer_total=$((${#RELAYS[@]} - 1))
    echo -e "  ${G}●${N} ${W}${host}${N}  ${D}${loc}${N}"
    echo -e "    ${C}nodes:${N} ${nodes}  ${C}peers:${N} ${peers_ok}/${peer_total}  ${C}topics:${N} ${local_t}/${fwd_t}  ${C}up:${N} ${uptime}"

    if [[ -n "$names" ]]; then
      for name in $names; do
        echo -e "      ${B}↳${N} ${name}"
      done
    fi
  done
  echo ""
}

# ── Relay control ───────────────────────────────────────────────────
stop_relay() {
  local idx=$1
  local host="${RELAY_SSH_HOSTS[$idx]}"
  local container="${RELAY_CONTAINERS[$idx]}"
  echo -e "  ${Y}⏸${N}  Stopping ${W}${RELAYS[$idx]}${N}..."
  ssh "${RELAY_SSH_USER}@${host}" "docker stop ${container}" >/dev/null 2>&1
  echo -e "  ${R}●${N}  ${RELAYS[$idx]} is ${R}DOWN${N} — nodes will failover within ~5s"
}

start_relay() {
  local idx=$1
  local host="${RELAY_SSH_HOSTS[$idx]}"
  local container="${RELAY_CONTAINERS[$idx]}"
  echo -e "  ${Y}▶${N}  Starting ${W}${RELAYS[$idx]}${N}..."
  ssh "${RELAY_SSH_USER}@${host}" "docker start ${container}" >/dev/null 2>&1
  echo -e "  ${G}●${N}  ${RELAYS[$idx]} is ${G}UP${N} — peering in ~3s"
}

stop_node() {
  local node="$1"
  echo -e "  ${Y}⏸${N}  Stopping ${W}${node}${N}..."
  ssh "${NODE_SSH_USER}@${node}.lab" "docker stop ${NODE_CONTAINER}" >/dev/null 2>&1
  echo -e "  ${R}●${N}  ${node} is ${R}DOWN${N}"
}

start_node() {
  local node="$1"
  echo -e "  ${Y}▶${N}  Starting ${W}${node}${N}..."
  ssh "${NODE_SSH_USER}@${node}.lab" "docker start ${NODE_CONTAINER}" >/dev/null 2>&1
  echo -e "  ${G}●${N}  ${node} is ${G}UP${N} — connecting in ~5s"
}

# ── Menu: pick relay ────────────────────────────────────────────────
pick_relay() {
  local action="$1"
  echo ""
  for i in "${!RELAYS[@]}"; do
    local status_icon
    if is_relay_running "$i"; then
      status_icon="${G}●${N}"
    else
      status_icon="${R}●${N}"
    fi
    echo -e "  ${W}$((i+1))${N}  ${status_icon} ${RELAYS[$i]}  ${D}${RELAY_LOCATIONS[$i]}${N}"
  done
  echo -e "  ${D}0  back${N}"
  echo ""
  read -rp "  > " choice
  if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#RELAYS[@]} )); then
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
    echo -e "  ${W}$((i+1))${N}  ${status_icon} ${node}"
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
  local all_targets=("${RELAYS[@]}" "${NODES[@]}")

  echo -e "\n${R}━━━ CHAOS MODE ━━━${N}  ${D}(interval: ${interval}s, Ctrl+C to stop)${N}\n"

  while true; do
    sleep "$interval"
    local target_idx=$((RANDOM % ${#all_targets[@]}))
    local target="${all_targets[$target_idx]}"
    local ts
    ts=$(date '+%H:%M:%S')

    if [[ "$target" == relay*.macula.io ]]; then
      local idx
      for i in "${!RELAYS[@]}"; do [[ "${RELAYS[$i]}" == "$target" ]] && idx=$i; done
      if is_relay_running "$idx"; then
        local running_count=0
        for j in "${!RELAYS[@]}"; do is_relay_running "$j" && running_count=$((running_count + 1)); done
        if [[ "$running_count" -le 1 ]]; then
          echo -e "  ${D}${ts}${N}  ${Y}skip${N} ${target} — last relay standing"
          continue
        fi
        echo -e "  ${D}${ts}${N}  ${R}kill${N} ${W}${target}${N}"
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
  for i in "${!RELAYS[@]}"; do
    if ! is_relay_running "$i"; then
      echo -e "  ${G}▶${N}  Starting ${W}${RELAYS[$i]}${N}..."
      start_relay "$i"
    fi
  done
  for node in "${NODES[@]}"; do
    if ! is_node_running "$node"; then
      echo -e "  ${G}▶${N}  Starting ${W}${node}${N}..."
      start_node "$node"
    fi
  done
  echo -e "\n  ${G}✓${N}  All components started"
}

# ── Main menu ───────────────────────────────────────────────────────
cleanup() {
  echo ""
  exit 0
}
trap cleanup INT

main_menu() {
  while true; do
    echo -e "\n${W}━━━ MACULA RELAY MESH DEMO ━━━${N}\n"
    echo -e "  ${W}1${N}  Show topology"
    echo -e "  ${W}2${N}  Stop a relay"
    echo -e "  ${W}3${N}  Start a relay"
    echo -e "  ${W}4${N}  Stop a node"
    echo -e "  ${W}5${N}  Start a node"
    echo -e "  ${R}6${N}  ${R}Chaos mode${N}  ${D}(randomly kill/heal components)${N}"
    echo -e "  ${G}7${N}  ${G}Heal all${N}  ${D}(start everything)${N}"
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
      q|Q) cleanup ;;
      "") ;;
      *) echo -e "  ${R}?${N}" ;;
    esac
  done
}

main_menu
