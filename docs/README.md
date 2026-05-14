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

The rendered OpenWrt files live under `files/etc/config/` and are copied
into the firmware image.

The generated network configuration is based on templates under `templates/`.

| Config | Path |
| --- | --- |
| Network | `files/etc/config/network` |
| DHCP | `files/etc/config/dhcp` |
| Firewall | `files/etc/config/firewall` |
| Wireless | `templates/wireless.tmpl` |

## Security Model

External application access is handled by Cloudflare ZTNA and IAM. Router and
infrastructure management use the local admin VLAN or the WireGuard management
backdoor.

OpenWrt enforces routed segmentation between VLANs. Same-VLAN traffic is not a
router firewall boundary and must be controlled by host firewalls, service auth,
or workload policies when needed.
