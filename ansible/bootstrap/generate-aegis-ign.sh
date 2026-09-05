#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
BUTANE_IMAGE=${BUTANE_IMAGE:-quay.io/coreos/butane:release}
BUTANE_SOURCE=${BUTANE_SOURCE:-"$SCRIPT_DIR/aegis.bu"}
IGNITION_OUTPUT=${IGNITION_OUTPUT:-"$SCRIPT_DIR/config.ign"}
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-"$HOME/.ssh/id_ed25519.pub"}
WIFI_SECURITY=${WIFI_SECURITY:-wpa-psk}

usage() {
  cat <<'USAGE'
Usage:
  generate-aegis-ign.sh
  generate-aegis-ign.sh --write IMAGE DEVICE

Environment overrides:
  BUTANE_IMAGE       Butane container image (default: quay.io/coreos/butane:release)
  BUTANE_SOURCE      Butane source path (default: aegis.bu beside this script)
  IGNITION_OUTPUT    Ignition output path (default: config.ign beside this script)
  SSH_PUBLIC_KEY     SSH public key passed to arm-image-installer
  WIFI_SSID          Wi-Fi SSID; prompted if unset in --write mode
  WIFI_PASS          Wi-Fi password; prompted if unset in --write mode
  WIFI_SECURITY      Wi-Fi security type (default: wpa-psk)
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

read_required() {
  prompt=$1
  value=$2

  if [ -z "$value" ]; then
    printf '%s' "$prompt" >&2
    IFS= read -r value
  fi

  if [ -z "$value" ]; then
    printf '%s\n' 'Error: a value is required.' >&2
    exit 1
  fi

  printf '%s' "$value"
}

read_secret() {
  value=$1

  if [ -z "$value" ]; then
    printf '%s' 'Wi-Fi password: ' >&2
    stty -echo
    IFS= read -r value
    stty echo
    printf '\n' >&2
  fi

  if [ -z "$value" ]; then
    printf '%s\n' 'Error: a value is required.' >&2
    exit 1
  fi

  printf '%s' "$value"
}

write_image=false
case $# in
  0)
    ;;
  3)
    if [ "$1" != '--write' ]; then
      usage >&2
      exit 2
    fi
    write_image=true
    IMAGE=$2
    DEVICE=$3
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

require_command podman

if [ ! -f "$BUTANE_SOURCE" ]; then
  printf 'Error: Butane source not found: %s\n' "$BUTANE_SOURCE" >&2
  exit 1
fi

OUTPUT_DIR=$(dirname "$IGNITION_OUTPUT")
if [ ! -d "$OUTPUT_DIR" ]; then
  printf 'Error: output directory not found: %s\n' "$OUTPUT_DIR" >&2
  exit 1
fi

umask 077
TEMP_OUTPUT=$(mktemp "$OUTPUT_DIR/.config.ign.XXXXXX")
trap 'rm -f "$TEMP_OUTPUT"' EXIT HUP INT TERM

podman run --rm -i "$BUTANE_IMAGE" --strict < "$BUTANE_SOURCE" > "$TEMP_OUTPUT"
mv "$TEMP_OUTPUT" "$IGNITION_OUTPUT"
trap - EXIT HUP INT TERM

printf 'Generated Ignition config: %s\n' "$IGNITION_OUTPUT"

if [ "$write_image" = false ]; then
  exit 0
fi

if [ ! -f "$IMAGE" ]; then
  printf 'Error: image not found: %s\n' "$IMAGE" >&2
  exit 1
fi

if [ ! -b "$DEVICE" ]; then
  printf 'Error: target is not a block device: %s\n' "$DEVICE" >&2
  exit 1
fi

if [ ! -f "$SSH_PUBLIC_KEY" ]; then
  printf 'Error: SSH public key not found: %s\n' "$SSH_PUBLIC_KEY" >&2
  exit 1
fi

require_command arm-image-installer
WIFI_SSID=$(read_required 'Wi-Fi SSID: ' "${WIFI_SSID:-}")
WIFI_PASS=$(read_secret "${WIFI_PASS:-}")

printf 'Writing %s to %s.\n' "$IMAGE" "$DEVICE" >&2
sudo arm-image-installer \
  --image="$IMAGE" \
  --target=rpi4 \
  --media="$DEVICE" \
  --ignition="$IGNITION_OUTPUT" \
  --addkey="$SSH_PUBLIC_KEY" \
  --resizefs \
  --wifi-ssid="$WIFI_SSID" \
  --wifi-pass="$WIFI_PASS" \
  --wifi-security="$WIFI_SECURITY"
