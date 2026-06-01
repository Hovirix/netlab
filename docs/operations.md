# OpenWrt Operations

This document describes how to review, validate, and safely deploy the OpenWrt
network policy.

## Workflow

The repository workflow is:

```text
apply (check-update -> check -> build -> sysupgrade)
```

Use `nix flake check` for repository validation and `nix run .#build` for local
secret rendering plus firmware build.

Use `nix run .#sysupgrade` only after reviewing the generated files and
confirming the management path is safe.

Generated config and build artifacts are cleaned automatically on commit via pre-commit.

Use `nix run .#apply` for the full end-to-end flow.

## Generated Files

| File | Role |
| --- | --- |
| `files/etc/config/network` | Interfaces, bridge VLANs, WAN, and WireGuard. |
| `files/etc/config/dhcp` | DHCP service and DHCP-provided DNS options. |
| `files/etc/config/firewall` | Zone policies, forwarding, and explicit allow rules. |
| `files/etc/config/wireless` | Rendered Wi-Fi radios and SSID network mapping when present. |

Templates live under `templates/`. When a template changes, run `nix flake check` and then `nix run .#build` to verify generated config and firmware.

## Deployment Safety

Before deploying, verify these access paths:

| Path | Required Before Hardening |
| --- | --- |
| Physical backup | `lan5` provides untagged access to `vlan10`. |
| Local admin | Admin client can get DHCP on `vlan10`. |
| Router SSH | `vlan10 -> router` TCP `22` works. |
| Router HTTPS | `vlan10 -> router` TCP `443` works if LuCI or HTTPS admin is used. |
| AdGuard Home UI | `vlan10 -> router` TCP `3000` works. |
| WireGuard | WAN UDP `51820` reaches the router. |
| VPN management | VPN peer can reach router SSH/HTTPS and required infra services. |

Do not remove the old working management path until local VLAN10 and WireGuard
access are both tested.

## Validation Commands

Run repository checks before building:

```bash
nix flake check
```

Run a full local build:

```bash
nix flake check
nix run .#build
```

Run full apply (warn on updates and continue):

```bash
nix run .#apply
```

After deploying to the router, validate firewall syntax before restarting it:

```bash
fw4 check
```

Restart firewall only after syntax validates:

```bash
service firewall restart
```

## Post-Deploy Checks

After applying a new image, test from each zone.

| Zone | Expected Result |
| --- | --- |
| `vlan10` | DHCP, DNS, WAN, router SSH/HTTPS, AdGuard Home UI, Proxmox, TrueNAS, Talos, Kubernetes. |
| `vlan20` | Static IP, DNS, WAN, SMB to TrueNAS. |
| `vlan30` | DHCP, DNS, WAN. |
| `vlan40` | DHCP, DNS, WAN, SMB to TrueNAS. |
| `vlan50` | DHCP, DNS, WAN only. |
| `vlan60` | DHCP and DNS only, no WAN and no internal access. |
| `vpn` | WAN plus router, AdGuard Home UI, Proxmox, TrueNAS, Talos, and Kubernetes management. |

For `vlan60`, DNS responses may still work because AdGuard Home runs on the
router. Direct Internet access should fail because there is no `vlan60 -> wan`
forwarding.

## WAN DHCPv6 Lease Refresh

The ISP-provided DHCPv6 lease for `wan6` lasts about 2.5 hours. If `wan6` is not
refreshed before the lease expires, the MAP-E uplink can become unroutable even
though the interface still appears configured.

The image enables `cron` and installs a root crontab that restarts MAP-E `wan`
and DHCPv6 `wan6` every 2 hours. `wan` is brought down first because it depends
on `wan6`, then `wan6` is brought back up before `wan`:

```text
0 */2 * * * /sbin/ifdown wan; /sbin/ifdown wan6; sleep 5; /sbin/ifup wan6; sleep 5; /sbin/ifup wan
0 0,12 * * * /sbin/reboot
```

After deploying, confirm `cron` is running and the `wan6` lease refresh does not
interrupt expected MAP-E routing longer than the planned interface restart.
The router also reboots daily at midnight and noon to force a clean WAN recovery
cycle.

## AdGuard Home

AdGuard Home is the DNS service for internal clients. `dnsmasq` has DNS disabled
with `option port '0'` and only provides DHCP.

AdGuard Home must listen on the VLAN gateway addresses or on all IPv4
interfaces. Required router DNS listener addresses are:

| VLAN | Router DNS Address |
| ---: | --- |
| 10 | `10.10.0.1` |
| 20 | `10.20.0.1` |
| 30 | `10.30.0.1` |
| 40 | `10.40.0.1` |
| 50 | `10.50.0.1` |
| 60 | `10.60.0.1` |

If DNS fails on a VLAN while DHCP works, check AdGuard Home binding first.

The AdGuard Home web UI is bound to the admin gateway `10.10.0.1:3000` and
should only be reachable from `vlan10` and `vpn` by firewall policy.

The AdGuard Home admin user is rendered from `templates/adguardhome.yaml.tmpl`
using `secrets/adguardhome.sops.yaml`. Store the AdGuardHome bcrypt password
hash in `user.password_hash`; do not store a plaintext password in the secret.

## Wireless Checks

The intended wireless placement is:

| SSID Band | Zone |
| --- | --- |
| 2.4 GHz | `vlan50` |
| 5 GHz | `vlan10` |

After building, confirm generated wireless config matches the template. A
stale rendered file can place untrusted clients on the wrong VLAN.

## Change Checklist

When adding a new VLAN:

1. Add the bridge VLAN to `network` or `network.tmpl`.
1. Add the interface with a stable gateway address.
1. Add DHCP only if the VLAN should hand out addresses.
1. Add a firewall zone with `input DROP`, `output ACCEPT`, and `forward REJECT`.
1. Add WAN forwarding only if the VLAN should have Internet access.
1. Add router input rules only for required local services.
1. Add cross-zone rules only for required source, destination, protocol, and port.
1. Update `docs/zero-trust-network.md` with the new policy.

When adding a new allow rule:

1. Use the rule name format `Allow-<SRC>-to-<DST>-<SERVICE>`.
1. Prefer one protocol per rule.
1. Specify `dest_port` for TCP and UDP rules.
1. Use `src_port` only when the protocol has a meaningful source port, such as DHCP.
1. Add `src_ip` and `dest_ip` when device addresses are stable.
1. Confirm the rule is routed traffic; same-VLAN traffic usually bypasses OpenWrt.

## Break-Glass Access

WireGuard is the remote management backdoor. It should remain independent of
Cloudflare, Authentik, Kubernetes, and reverse proxies.

Recommended controls:

- Use one WireGuard peer per device.
- Keep each peer on a fixed `/32` address.
- Restrict high-risk rules by `src_ip` once peer roles are stable.
- Remove lost or retired peer keys immediately.
- Keep Proxmox, TrueNAS, and SSH authentication strong even when the VPN works.

## Future Tightening

The current policy is zone-scoped. It can be tightened later with stable IPs.

Recommended next restrictions:

| Flow | Future Restriction |
| --- | --- |
| Admin to Proxmox | Limit `src_ip` to admin clients and `dest_ip` to Proxmox nodes. |
| Admin to TrueNAS | Limit `src_ip` to admin clients and `dest_ip` to TrueNAS. |
| VPN to infra | Limit by WireGuard peer IP. |
| SMB to TrueNAS | Limit `dest_ip` to TrueNAS and sources to exact Proxmox/Kubernetes hosts. |
| Router admin | Limit SSH/HTTPS to admin laptop and trusted VPN peers. |

Do not add broad rules for convenience without documenting the reason and the
expected removal or tightening path.
