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

The rendered OpenWrt files live under `build/staged-files/`, then are passed to
OpenWrt ImageBuilder. That directory is disposable and should not be committed.

Non-secret policy lives under `config/`. Secrets live under `secrets/`. Runtime
files are generated from templates under `templates/`.

| Config | Path |
| --- | --- |
| Network policy | `config/network.yaml` + `templates/network.tmpl` |
| DHCP | `config/network.yaml` + `templates/dhcp.tmpl` |
| Firewall | `config/firewall.yaml` + `templates/firewall.tmpl` |
| Wireless | `templates/wireless.tmpl` + `secrets/wireless.sops.yaml` |
| AdGuardHome | `templates/adguardhome.yaml.tmpl` + `secrets/adguardhome.sops.yaml` |

## Security Model

External application access is handled by Cloudflare ZTNA and IAM. Router and
infrastructure management use the local admin VLAN or the WireGuard management
backdoor.

OpenWrt enforces routed segmentation between VLANs. Same-VLAN traffic is not a
router firewall boundary and must be controlled by host firewalls, service auth,
or workload policies when needed.
