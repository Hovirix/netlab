#!/usr/bin/env bash
set -euo pipefail

rm -rf build/generated build/files

mkdir -p \
  build/generated \
  build/files/etc/config \
  build/files/etc/adguardhome \
  build/files/etc/dropbear \
  build/files/etc/crontabs \
  build/files/etc/uci-defaults

sops -d config/secrets.sops.yaml >build/generated/secrets.yaml

gomplate_args=(
  --datasource config=config/router.yaml
  --datasource secrets=build/generated/secrets.yaml
)

gomplate "${gomplate_args[@]}" --file templates/network.tmpl --out build/files/etc/config/network
gomplate "${gomplate_args[@]}" --file templates/dhcp.tmpl --out build/files/etc/config/dhcp
gomplate "${gomplate_args[@]}" --file templates/firewall.tmpl --out build/files/etc/config/firewall
gomplate "${gomplate_args[@]}" --file templates/wireless.tmpl --out build/files/etc/config/wireless
gomplate "${gomplate_args[@]}" --file templates/dropbear.tmpl --out build/files/etc/config/dropbear
gomplate "${gomplate_args[@]}" --file templates/adguardhome.yaml.tmpl --out build/files/etc/adguardhome/adguardhome.yaml
gomplate "${gomplate_args[@]}" --file templates/authorized_keys.tmpl --out build/files/etc/dropbear/authorized_keys
gomplate "${gomplate_args[@]}" --file templates/root-crontab.tmpl --out build/files/etc/crontabs/root
gomplate "${gomplate_args[@]}" --file templates/99-service.tmpl --out build/files/etc/uci-defaults/99-service

chmod +x build/files/etc/uci-defaults/99-service
