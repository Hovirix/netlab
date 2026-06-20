# Documentation

This directory documents the intended network policy behind the Gomplate-rendered
OpenWrt configuration. The goal is to make generated UCI files reviewable without
reading every firewall rule directly.

## Documents

| File | Purpose |
| --- | --- |
| [`zero-trust-network.md`](zero-trust-network.md) | VLAN model, trust boundaries, forwarding policy, and allowed flows. |
| [`operations.md`](operations.md) | Build, validation, deployment safety, and change checklist. |

## Source Of Truth

The non-secret model lives in `config/router.yaml`. Runtime secrets live in
`config/secrets.sops.yaml`. Templates under `templates/` render final OpenWrt
files into `build/files/`, which is passed to ImageBuilder as the firmware
overlay.

| Config | Rendered Path |
| --- | --- |
| Network | `build/files/etc/config/network` |
| DHCP | `build/files/etc/config/dhcp` |
| Firewall | `build/files/etc/config/firewall` |
| Wireless | `build/files/etc/config/wireless` |
| Dropbear | `build/files/etc/config/dropbear` |
| Authorized keys | `build/files/etc/dropbear/authorized_keys` |
| Root crontab | `build/files/etc/crontabs/root` |
| UCI defaults | `build/files/etc/uci-defaults/99-service` |
| AdGuardHome | `build/files/etc/adguardhome/adguardhome.yaml` |
