#!/usr/bin/env bash
set -euo pipefail

if [ -n "${NETLAB_ROOT:-}" ]; then
  repo_root="$NETLAB_ROOT"
else
  repo_root="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
fi
cd "$repo_root"
build_dir="${BUILD_DIR:-$repo_root/build}"
generated_dir="$build_dir/generated"
stage_dir="$build_dir/files"
config_dir="$stage_dir/etc/config"
adguardhome_dir="$stage_dir/etc/adguardhome"
dropbear_dir="$stage_dir/etc/dropbear"
crontabs_dir="$stage_dir/etc/crontabs"
uci_defaults_dir="$stage_dir/etc/uci-defaults"

rm -rf "$generated_dir" "$stage_dir"
mkdir -p "$generated_dir" "$config_dir" "$adguardhome_dir" "$dropbear_dir" "$crontabs_dir" "$uci_defaults_dir"

secrets_source="${SECRETS_FILE:-$repo_root/config/secrets.sops.yaml}"

if [ ! -r "$secrets_source" ]; then
  printf 'Error: secrets file not found or unreadable: %s\n' "$secrets_source" >&2
  exit 1
fi

sops -d "$secrets_source" >"$generated_dir/secrets.yaml"

gomplate_args=(
  --datasource "config=file://$repo_root/config/router.yaml"
  --datasource "secrets=file://$generated_dir/secrets.yaml"
)

gomplate "${gomplate_args[@]}" --file "$repo_root/templates/network.tmpl" --out "$config_dir/network"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/dhcp.tmpl" --out "$config_dir/dhcp"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/firewall.tmpl" --out "$config_dir/firewall"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/wireless.tmpl" --out "$config_dir/wireless"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/dropbear.tmpl" --out "$config_dir/dropbear"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/adguardhome.yaml.tmpl" --out "$adguardhome_dir/adguardhome.yaml"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/authorized_keys.tmpl" --out "$dropbear_dir/authorized_keys"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/root-crontab.tmpl" --out "$crontabs_dir/root"
gomplate "${gomplate_args[@]}" --file "$repo_root/templates/99-service.tmpl" --out "$uci_defaults_dir/99-service"
chmod +x "$uci_defaults_dir/99-service"

printf 'Rendered OpenWrt overlay: %s\n' "$stage_dir"
