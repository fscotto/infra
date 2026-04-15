#!/bin/bash

runvm() {
  local vm state choice count i ip

  if ! command -v virsh >/dev/null 2>&1; then
    printf '%s\n' "runvm: virsh is required (libvirt)" >&2
    return 1
  fi

  sudo -v

  local line
  vms=()
  while IFS= read -r line; do
    [ -n "$line" ] && vms+=("$line")
  done < <(sudo virsh list --all --name)

  if [ ${#vms[@]} -eq 0 ]; then
    printf '%s\n' "runvm: no VMs found" >&2
    return 1
  fi

  printf '\n%s\n' "VMs:"
  count=1
  for i in "${!vms[@]}"; do
    state=$(sudo virsh dominfo "${vms[$i]}" 2>/dev/null | awk '/^State:/ {print $2}')
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
  state=$(sudo virsh dominfo "$vm" 2>/dev/null | awk '/^State:/ {print $2}')

  printf '\nSelected: %s\n' "$vm"

  if [ "$state" = "running" ]; then
    printf '  VM is already running.\n'
    ip=$(_runvm_get_ip "$vm")
    if [ -n "$ip" ] && [ "$ip" != "<unknown>" ]; then
      printf '  IP: %s\n' "$ip"
    fi
    return 0
  fi

  printf 'Starting %s...\n' "$vm"
  if ! sudo virsh start "$vm"; then
    printf '  failed to start %s\n' "$vm" >&2
    return 1
  fi

  printf '  %s started.\n' "$vm"
  printf '  Waiting for IP...\n'
  ip=$(_runvm_get_ip "$vm")

  if [ -n "$DISPLAY" ] && command -v notify-send >/dev/null 2>&1; then
    notify-send "$vm started" "IP: $ip" 2>/dev/null
  fi

  printf '  IP: %s\n' "$ip"

  return 0
}

_runvm_get_ip() {
  local vm="$1"
  local mac network ip i

  mac=$(sudo virsh dumpxml "$vm" | awk -F"'" '/mac address/ {print $2}')
  [ -z "$mac" ] && return 1

  network=$(sudo virsh dumpxml "$vm" | awk -F"'" '/source network/ {print $2}')
  [ -z "$network" ] && return 1

  for i in $(seq 15); do
    ip=$(sudo virsh net-dhcp-leases "$network" 2>/dev/null | \
         awk -v m="$mac" '$3 == m {print $5}' | cut -d/ -f1)
    [ -n "$ip" ] && break
    sleep 2
  done

  printf '%s' "${ip:-<unknown>}"
}
