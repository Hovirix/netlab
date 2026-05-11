#!/usr/bin/env bash
# shellcheck source=./common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

NETWORK_SECRET="${NETWORK_SECRET:-$REPO_ROOT/secrets/network.sops.yaml}"
WIRELESS_SECRET="${WIRELESS_SECRET:-$REPO_ROOT/secrets/wireless.sops.yaml}"

require_cmd sops gomplate

if [ ! -r "$NETWORK_SECRET" ]; then
  printf 'Error: network secret file not found or unreadable: %s\n' "$NETWORK_SECRET" >&2
  exit 1
fi

if [ ! -r "$WIRELESS_SECRET" ]; then
  printf 'Error: wireless secret file not found or unreadable: %s\n' "$WIRELESS_SECRET" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
network_yaml="$tmp_dir/network.yaml"
wireless_yaml="$tmp_dir/wireless.yaml"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$CONFIG_DIR"

printf 'Decrypting secret files\n'
sops -d "$NETWORK_SECRET" >"$network_yaml"
sops -d "$WIRELESS_SECRET" >"$wireless_yaml"

printf 'Rendering OpenWrt config templates\n'
gomplate \
  --datasource "network=file://$network_yaml" \
  --datasource "wireless=file://$wireless_yaml" \
  --file "$OPENWRT_DIR/templates/network.tmpl" \
  --out "$CONFIG_DIR/network"

gomplate \
  --datasource "network=file://$network_yaml" \
  --datasource "wireless=file://$wireless_yaml" \
  --file "$OPENWRT_DIR/templates/wireless.tmpl" \
  --out "$CONFIG_DIR/wireless"

printf 'Rendered: %s/network\n' "$CONFIG_DIR"
printf 'Rendered: %s/wireless\n' "$CONFIG_DIR"
