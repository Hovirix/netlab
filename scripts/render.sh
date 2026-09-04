#!/usr/bin/env bash
set -euo pipefail

umask 077

stage="build/files"
secrets="config/secrets.sops.yaml"

rm -rf "$stage"
mkdir -p "$stage/etc/"{config,adguardhome,dropbear,crontabs,uci-defaults}

if [ ! -r "$secrets" ]; then
  printf 'Error: secrets file not found or unreadable: %s\n' "$secrets" >&2
  exit 1
fi

sops -d "$secrets" |
  gomplate \
    -d config=config/router.yaml \
    -d secrets=stdin:///secrets.yaml \
    -f templates/dhcp.tmpl -o "$stage/etc/config/dhcp" \
    -f templates/network.tmpl -o "$stage/etc/config/network" \
    -f templates/firewall.tmpl -o "$stage/etc/config/firewall" \
    -f templates/wireless.tmpl -o "$stage/etc/config/wireless" \
    -f templates/dropbear.tmpl -o "$stage/etc/config/dropbear" \
    -f templates/adguardhome.yaml.tmpl -o "$stage/etc/adguardhome/adguardhome.yaml" \
    -f templates/authorized_keys.tmpl -o "$stage/etc/dropbear/authorized_keys" \
    -f templates/root-crontab.tmpl -o "$stage/etc/crontabs/root" \
    -f templates/99-service.tmpl -o "$stage/etc/uci-defaults/99-service"

chmod +x "$stage/etc/uci-defaults/99-service"
