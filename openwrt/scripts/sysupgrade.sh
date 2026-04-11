#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

: "${ROUTER_HOST:?ROUTER_HOST must be set}"
: "${ROUTER_USER:?ROUTER_USER must be set}"
ROUTER_PORT="${ROUTER_PORT:-22}"

require_cmd scp ssh

artifact_dir="$IMAGE_BUILDER_DIR/bin/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET"
artifact_name="openwrt-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}-${OPENWRT_PROFILE}-squashfs-sysupgrade.bin"
artifact_path="$artifact_dir/$artifact_name"

if [ ! -f "$artifact_path" ]; then
  printf 'Error: expected sysupgrade image not found: %s\n' "$artifact_path" >&2
  exit 1
fi

remote_path="/tmp/$artifact_name"

printf 'Uploading firmware to %s@%s:%s\n' "$ROUTER_USER" "$ROUTER_HOST" "$remote_path"
scp -O -P "$ROUTER_PORT" "$artifact_path" "$ROUTER_USER@$ROUTER_HOST:$remote_path"

printf '\n!!! WARNING: This will reboot the router. Do not power it off during upgrade. !!!\n\n'
read -r -p 'Are you sure you want to run sysupgrade? [y/N] ' confirm
if [[ "$confirm" != [yY] ]]; then
  printf 'Aborted. Firmware was uploaded to %s\n' "$remote_path"
  exit 1
fi

printf 'Running sysupgrade on router\n'
ssh -p "$ROUTER_PORT" "$ROUTER_USER@$ROUTER_HOST" "sysupgrade '$remote_path'"
