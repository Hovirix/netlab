#!/usr/bin/env bash
set -euo pipefail

config_dir="build/files/etc/config"

for config in network dhcp firewall wireless dropbear; do
  uci -c "$config_dir" -q show "$config" >/dev/null
done

test -s build/files/etc/adguardhome/adguardhome.yaml
test -s build/files/etc/dropbear/authorized_keys
test -s build/files/etc/crontabs/root
test -x build/files/etc/uci-defaults/99-service

printf 'Gomplate render and UCI validation passed\n'
