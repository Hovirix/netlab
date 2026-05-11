#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_cmd curl sort

releases_url="https://downloads.openwrt.org/releases/"

latest_version="$({
  curl -fsSL "$releases_url" | sed -n 's|.*href="\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)/".*|\1|p'
} | sort -V | tail -n 1)"

if [ -z "$latest_version" ]; then
  printf 'Error: could not determine latest OpenWrt release from %s\n' "$releases_url" >&2
  exit 1
fi

printf 'Current version: %s\n' "$OPENWRT_VERSION"
printf 'Latest version:  %s\n' "$latest_version"

if [ "$OPENWRT_VERSION" = "$latest_version" ]; then
  printf 'OpenWrt is up to date.\n'
  exit 0
fi

printf 'Update available: %s -> %s\n' "$OPENWRT_VERSION" "$latest_version"
printf 'LATEST_OPENWRT_VERSION=%s\n' "$latest_version"
exit 0
