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

Non-secret policy lives in `config/default.yml`. Secrets live in `secrets/secrets.sops.yaml`.
Runtime files are generated from Jinja templates under `templates/files/`.
Python workflow dependencies are locked in `uv.lock` and exposed through the
uv2nix-backed `nix develop` shell.

| Config | Path |
| --- | --- |
| Network policy | `config/default.yml` + `templates/files/network.j2` |
| DHCP | `config/default.yml` + `templates/files/dhcp.j2` |
| Firewall | `config/default.yml` + `templates/files/firewall.j2` |
| Cron | `config/default.yml` + `templates/files/crontab.j2` |
| SSH authorized keys | `config/default.yml` + `templates/files/authorized_keys.j2` |
| Wireless | `templates/files/wireless.j2` + `secrets/secrets.sops.yaml` |
| AdGuardHome | `templates/files/adguardhome.yaml.j2` + `secrets/secrets.sops.yaml` |

## Security Model

External application access is handled by Cloudflare ZTNA and IAM. Router and
infrastructure management use the local admin VLAN or the WireGuard management
backdoor.

OpenWrt enforces routed segmentation between VLANs. Same-VLAN traffic is not a
router firewall boundary and must be controlled by host firewalls, service auth,
or workload policies when needed.
