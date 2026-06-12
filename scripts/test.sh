#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${NETLAB_ROOT:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}"
stage_dir="${TEST_STAGE_DIR:-$repo_root/build/test-staged-files}"

NETWORK_SECRET_DATA="$repo_root/tests/fixtures/network.yaml" \
	WIRELESS_SECRET_DATA="$repo_root/tests/fixtures/wireless.yaml" \
	ADGUARDHOME_SECRET_DATA="$repo_root/tests/fixtures/adguardhome.yaml" \
	STAGE_DIR="$stage_dir" \
	"$repo_root/scripts/render.sh"

config_dir="$stage_dir/etc/config"

for config in network dhcp firewall wireless dropbear; do
	uci -c "$config_dir" -q show "$config" >/dev/null
done

test -s "$stage_dir/etc/adguardhome/adguardhome.yaml"
test -x "$stage_dir/etc/uci-defaults/99-service"

printf 'Rendered UCI validation passed: %s\n' "$config_dir"
