#!/usr/bin/env bash
set -euo pipefail

if [ -n "${NETLAB_ROOT:-}" ]; then
  repo_root="$NETLAB_ROOT"
else
  repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
fi

"$repo_root/scripts/render.sh"

config_dir="${BUILD_DIR:-$repo_root/build}/files/etc/config"
uci -c "$config_dir" -q show network >/dev/null
uci -c "$config_dir" -q show dhcp >/dev/null
uci -c "$config_dir" -q show firewall >/dev/null
uci -c "$config_dir" -q show wireless >/dev/null
uci -c "$config_dir" -q show dropbear >/dev/null
test -s "${BUILD_DIR:-$repo_root/build}/files/etc/adguardhome/adguardhome.yaml"
test -s "${BUILD_DIR:-$repo_root/build}/files/etc/dropbear/authorized_keys"
test -s "${BUILD_DIR:-$repo_root/build}/files/etc/crontabs/root"
test -x "${BUILD_DIR:-$repo_root/build}/files/etc/uci-defaults/99-service"

printf 'Gomplate render and UCI validation passed\n'
