# Documentation

This directory documents the intended network policy behind the OpenWrt
configuration. The goal is to make the generated UCI files reviewable without
reading every firewall rule directly.

## Documents

| File | Purpose |
| --- | --- |
| [`zero-trust-network.md`](zero-trust-network.md) | VLAN model, trust boundaries, forwarding policy, and allowed flows. |
| [`operations.md`](operations.md) | Deployment, validation, break-glass access, and change checklist. |

## Source Of Truth

Rendered OpenWrt files will live under `build/staged-files/`, then be passed to
OpenWrt ImageBuilder. That directory is disposable and should not be committed.

Non-secret policy lives under `config/`. Secrets live in `secrets.sops.yaml`.
Runtime files are generated from Jinja templates under `templates/`.

| Config | Path |
| --- | --- |
| Network policy | `config/network.yaml` + `templates/network.j2` |
| DHCP | `config/network.yaml` + `templates/dhcp.j2` |
| Firewall | `config/firewall.yaml` + `templates/firewall.j2` |
| Cron | `config/services.yaml` + `templates/crontab.j2` |
| SSH authorized keys | `config/services.yaml` + `templates/authorized_keys.j2` |
| Wireless | `templates/wireless.j2` + `secrets.sops.yaml` |
| AdGuardHome | `templates/adguardhome.yaml.j2` + `secrets.sops.yaml` |

## Security Model

External application access is handled by Cloudflare ZTNA and IAM. Router and
infrastructure management use the local admin VLAN or the WireGuard management
backdoor.

OpenWrt enforces routed segmentation between VLANs. Same-VLAN traffic is not a
router firewall boundary and must be controlled by host firewalls, service auth,
or workload policies when needed.
