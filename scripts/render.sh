#!/usr/bin/env bash
set -euo pipefail

generated_dir="build/generated"
stage_dir="build/files"
config_dir="$stage_dir/etc/config"
adguardhome_dir="$stage_dir/etc/adguardhome"
dropbear_dir="$stage_dir/etc/dropbear"
crontabs_dir="$stage_dir/etc/crontabs"
uci_defaults_dir="$stage_dir/etc/uci-defaults"

rm -rf "$generated_dir" "$stage_dir"
mkdir -p "$generated_dir" "$config_dir" "$adguardhome_dir" "$dropbear_dir" "$crontabs_dir" "$uci_defaults_dir"

secrets_source="config/secrets.sops.yaml"

if [ ! -r "$secrets_source" ]; then
  printf 'Error: secrets file not found or unreadable: %s\n' "$secrets_source" >&2
  exit 1
fi

sops -d "$secrets_source" >"$generated_dir/secrets.yaml"

gomplate_args=(
  --datasource "config=file://$PWD/config/router.yaml"
  --datasource "secrets=file://$PWD/$generated_dir/secrets.yaml"
)

outputs=(
  "network.tmpl:$config_dir/network"
  "dhcp.tmpl:$config_dir/dhcp"
  "firewall.tmpl:$config_dir/firewall"
  "wireless.tmpl:$config_dir/wireless"
  "dropbear.tmpl:$config_dir/dropbear"
  "adguardhome.yaml.tmpl:$adguardhome_dir/adguardhome.yaml"
  "authorized_keys.tmpl:$dropbear_dir/authorized_keys"
  "root-crontab.tmpl:$crontabs_dir/root"
  "99-service.tmpl:$uci_defaults_dir/99-service"
)

for output in "${outputs[@]}"; do
  gomplate "${gomplate_args[@]}" --file "templates/${output%%:*}" --out "${output#*:}"
done
chmod +x "$uci_defaults_dir/99-service"

printf 'Rendered OpenWrt overlay: %s\n' "$stage_dir"
