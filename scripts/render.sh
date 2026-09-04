#!/usr/bin/env bash
set -euo pipefail

rm -rf build/generated build/files

mkdir -p \
  build/files/etc/config \
  build/files/etc/adguardhome \
  build/files/etc/dropbear \
  build/files/etc/crontabs \
  build/files/etc/uci-defaults

secrets_yaml="$(sops -d config/secrets.sops.yaml)"

gomplate_args=(
  --datasource config=config/router.yaml
  --datasource secrets=stdin:///secrets.yaml
)

printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/network.tmpl --out build/files/etc/config/network
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/dhcp.tmpl --out build/files/etc/config/dhcp
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/firewall.tmpl --out build/files/etc/config/firewall
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/wireless.tmpl --out build/files/etc/config/wireless
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/dropbear.tmpl --out build/files/etc/config/dropbear
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/adguardhome.yaml.tmpl --out build/files/etc/adguardhome/adguardhome.yaml
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/authorized_keys.tmpl --out build/files/etc/dropbear/authorized_keys
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/root-crontab.tmpl --out build/files/etc/crontabs/root
printf '%s\n' "$secrets_yaml" | gomplate "${gomplate_args[@]}" --file templates/99-service.tmpl --out build/files/etc/uci-defaults/99-service

chmod +x build/files/etc/uci-defaults/99-service
