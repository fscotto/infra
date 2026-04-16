#!/bin/bash

runvm() {
  local vm state choice count i ip conn="qemu:///system"

  if ! command -v virsh >/dev/null 2>&1; then
    printf '%s\n' "runvm: virsh is required (libvirt)" >&2
    return 1
  fi

  local line
  vms=()
  while IFS= read -r line; do
    [ -n "$line" ] && vms+=("$line")
  done < <(virsh --connect "$conn" list --all --name)

  if [ ${#vms[@]} -eq 0 ]; then
    printf '%s\n' "runvm: no VMs found" >&2
    return 1
  fi

  printf '\n%s\n' "VMs:"
  count=1
  for i in "${!vms[@]}"; do
    state=$(virsh --connect "$conn" dominfo "${vms[$i]}" 2>/dev/null | awk '/^State:/ {print $2}')
    printf '  %d) %-30s [%s]\n' "$((count++))" "${vms[$i]}" "${state:-unknown}"
  done
  printf '\n'

  read -p "Select VM (1-${#vms[@]}) or 'q' to quit: " choice

  if [ "$choice" = "q" ] || [ -z "$choice" ]; then
    return 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#vms[@]}" ]; then
    printf '%s\n' "runvm: invalid choice" >&2
    return 1
  fi

  vm="${vms[$((choice - 1))]}"
  state=$(virsh --connect "$conn" dominfo "$vm" 2>/dev/null | awk '/^State:/ {print $2}')

  printf '\nSelected: %s\n' "$vm"

  if [ "$state" = "running" ]; then
    printf '  VM is already running.\n'
    ip=$(_runvm_get_ip "$vm" "$conn")
    if [ -n "$ip" ] && [ "$ip" != "<unknown>" ]; then
      printf '  IP: %s\n' "$ip"
    fi
    return 0
  fi

  printf 'Starting %s...\n' "$vm"
  if ! virsh --connect "$conn" start "$vm"; then
    printf '  failed to start %s\n' "$vm" >&2
    return 1
  fi

  printf '  %s started.\n' "$vm"
  printf '  Waiting for IP...\n'
  ip=$(_runvm_get_ip "$vm" "$conn")

  if [ "$ip" != "<unknown>" ]; then
    _runvm_update_hosts "$vm" "$ip"
    printf '  IP: %s\n' "$ip"
  else
    printf '  IP: %s\n' "$ip"
  fi

  if [ -n "$DISPLAY" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "$vm started" "IP: $ip" 2>/dev/null
  fi

  return 0
}

_runvm_normalize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'
}

_runvm_update_hosts() {
  local vm="$1" ip="$2"
  local alias short

  alias=$(_runvm_normalize_name "$vm")
  short="${alias}.localdomain"

  sudo sed -i "/ ${alias}$/d; /^${ip} /d" /etc/hosts 2>/dev/null
  printf '%s  %s %s\n' "$ip" "$short" "$alias" | sudo tee -a /etc/hosts >/dev/null
}

_runvm_get_ip() {
  local vm="$1" conn="$2" mac network ip i

  mac=$(virsh --connect "$conn" dumpxml "$vm" | awk -F"'" '/mac address/ {print $2}')
  [ -z "$mac" ] && return 1

  network=$(virsh --connect "$conn" dumpxml "$vm" | awk -F"'" '/source network/ {print $2}')
  [ -z "$network" ] && return 1

  for i in $(seq 15); do
    ip=$(virsh --connect "$conn" net-dhcp-leases "$network" 2>/dev/null | \
         awk -v m="$mac" '$3 == m {print $5}' | cut -d/ -f1)
    [ -n "$ip" ] && break
    sleep 2
  done

  printf '%s' "${ip:-<unknown>}"
}
