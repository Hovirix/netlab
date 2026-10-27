#!/usr/bin/env bash
set -euo pipefail

config_dir="${OVERLAY_DIR:?}/etc/config"

for config in network dhcp firewall wireless dropbear; do
  uci -c "$config_dir" -q show "$config" >/dev/null
done

test -s "$OVERLAY_DIR/etc/adguardhome/adguardhome.yaml"
test -s "$OVERLAY_DIR/etc/dropbear/authorized_keys"
test -x "$OVERLAY_DIR/etc/uci-defaults/99-service"
