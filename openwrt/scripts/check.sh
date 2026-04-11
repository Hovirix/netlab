#!/usr/bin/env bash

# shellcheck source=./common.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

require_cmd gomplate

for file in "$OPENWRT_DIR/templates/network.tmpl" "$OPENWRT_DIR/templates/wireless.tmpl"; do
	if [ ! -f "$file" ]; then
		printf 'Error: required template not found: %s\n' "$file" >&2
		exit 1
	fi
done

for file in "$OPENWRT_DIR/files/config/network" "$OPENWRT_DIR/files/config/wireless"; do
	if [ ! -f "$file" ]; then
		printf 'Note: %s missing; run render to generate it\n' "$file"
	fi
done

if command -v uci >/dev/null 2>&1; then
	if [ -f "$OPENWRT_DIR/files/config/network" ]; then
		uci -c "$CONFIG_DIR" -q show network >/dev/null
	fi
	if [ -f "$OPENWRT_DIR/files/config/wireless" ]; then
		uci -c "$CONFIG_DIR" -q show wireless >/dev/null
	fi
else
	printf 'Note: uci command not found; skipping UCI syntax validation\n'
fi

printf 'Checks passed\n'
