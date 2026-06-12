#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${NETLAB_ROOT:-$(CDPATH='' cd -- "$script_dir/.." && pwd)}"

# shellcheck source=/dev/null
source "$repo_root/config/openwrt.env"

build_dir="${BUILD_DIR:-$repo_root/build}"
stage_dir="${STAGE_DIR:-$build_dir/staged-files}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

network_data="${NETWORK_DATA:-$repo_root/config/network.yaml}"
firewall_data="${FIREWALL_DATA:-$repo_root/config/firewall.yaml}"
network_secret_data="${NETWORK_SECRET_DATA:-}"
wireless_secret_data="${WIRELESS_SECRET_DATA:-}"
adguardhome_secret_data="${ADGUARDHOME_SECRET_DATA:-}"

if [ -z "$network_secret_data" ]; then
	network_secret="${NETWORK_SECRET:-$repo_root/secrets/network.sops.yaml}"
	network_secret_data="$tmp_dir/network-secret.yaml"
	sops -d "$network_secret" >"$network_secret_data"
fi

if [ -z "$wireless_secret_data" ]; then
	wireless_secret="${WIRELESS_SECRET:-$repo_root/secrets/wireless.sops.yaml}"
	wireless_secret_data="$tmp_dir/wireless-secret.yaml"
	sops -d "$wireless_secret" >"$wireless_secret_data"
fi

if [ -z "$adguardhome_secret_data" ]; then
	adguardhome_secret="${ADGUARDHOME_SECRET:-$repo_root/secrets/adguardhome.sops.yaml}"
	adguardhome_secret_data="$tmp_dir/adguardhome-secret.yaml"
	sops -d "$adguardhome_secret" >"$adguardhome_secret_data"
fi

rm -rf "$stage_dir"
mkdir -p "$stage_dir"

if [ -d "$repo_root/files" ]; then
	cp -R "$repo_root/files/." "$stage_dir/"
fi

render_template() {
	local template="$1"
	local output="$2"

	mkdir -p "$(dirname -- "$stage_dir/$output")"
	gomplate \
		--datasource "network=file://$network_data" \
		--datasource "firewall=file://$firewall_data" \
		--datasource "network_secret=file://$network_secret_data" \
		--datasource "wireless=file://$wireless_secret_data" \
		--datasource "adguardhome=file://$adguardhome_secret_data" \
		--file "$repo_root/templates/$template" \
		--out "$stage_dir/$output"
}

render_template network.tmpl etc/config/network
render_template dhcp.tmpl etc/config/dhcp
render_template firewall.tmpl etc/config/firewall
render_template wireless.tmpl etc/config/wireless
render_template dropbear.tmpl etc/config/dropbear
render_template adguardhome.yaml.tmpl etc/adguardhome/adguardhome.yaml
render_template 99-service.tmpl etc/uci-defaults/99-service

chmod 0755 "$stage_dir/etc/uci-defaults/99-service"

printf 'Rendered staged files: %s\n' "$stage_dir"
