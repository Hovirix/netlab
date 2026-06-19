# Zero-Trust Network

This network uses default-deny routed segmentation. Each VLAN has one security
role, and cross-zone traffic is allowed only when a rule explicitly describes the
source, destination, protocol, and destination port.

The source of truth is `config/router.yaml` plus encrypted
`config/secrets.sops.yaml`. Final OpenWrt files are rendered into `build/files/`
and are not tracked in Git.

## Design Goals

- Keep public application access outside the LAN policy by using Cloudflare ZTNA
  and IAM.
- Keep a direct WireGuard management path for break-glass access.
- Prevent untrusted Wi-Fi and lab systems from reaching internal infrastructure.
- Separate admin clients, hypervisor management, storage, Kubernetes, untrusted
  devices, and lab workloads.
- Make firewall intent readable with stable rule names.

## VLANs

| VLAN | Zone | Gateway | DHCP | WAN | Purpose |
| ---: | --- | --- | --- | --- | --- |
| 10 | `vlan10` | `10.10.0.1/24` | yes | yes | Admin clients and physical backup access. |
| 20 | `vlan20` | `10.20.0.1/24` | no | yes | Mini PC and Proxmox host management. |
| 30 | `vlan30` | `10.30.0.1/24` | yes | yes | TrueNAS and storage services. |
| 40 | `vlan40` | `10.40.0.1/24` | yes | yes | Talos Linux and Kubernetes nodes. |
| 50 | `vlan50` | `10.50.0.1/24` | yes | yes | Untrusted Wi-Fi and client devices. |
| 60 | `vlan60` | `10.60.0.1/24` | yes | no | Security lab VMs. |

The `vpn` zone is a WireGuard interface, not a VLAN. It is separate from
`vlan10` so remote management can be audited and restricted independently.

## Switch Ports

| Port | Mode | VLANs |
| --- | --- | --- |
| `lan1` | trunk | tagged `10`, `20`, `30`, `40`, `50`, `60` |
| `lan2` | trunk | tagged `10`, `20`, `30`, `40`, `50`, `60` |
| `lan3` | access | untagged `30` |
| `lan4` | unused | none |
| `lan5` | access | untagged `10` |

`lan1` and `lan2` are full tagged trunks for mini PCs. `lan3` is the direct
TrueNAS port and lands on the storage VLAN. `lan5` is the physical backup access
port. Keep `lan5` physically trusted because it lands directly on the admin
VLAN.

## Zone Policy

| Zone | Input | Output | Forward | Masquerade |
| --- | --- | --- | --- | --- |
| `wan` | `DROP` | `ACCEPT` | `DROP` | yes |
| `vlan10` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vlan20` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vlan30` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vlan40` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vlan50` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vlan60` | `DROP` | `ACCEPT` | `REJECT` | no |
| `vpn` | `DROP` | `ACCEPT` | `REJECT` | no |

## WAN Forwarding

| Source | Destination | Status | Reason |
| --- | --- | --- | --- |
| `vlan10` | `wan` | allowed | Admin client Internet. |
| `vlan20` | `wan` | allowed | Proxmox updates. |
| `vlan30` | `wan` | allowed | TrueNAS updates. |
| `vlan40` | `wan` | allowed | Kubernetes image pulls and updates. |
| `vlan50` | `wan` | allowed | Untrusted Wi-Fi Internet. |
| `vlan60` | `wan` | blocked | Lab has no Internet by default. |
| `vpn` | `wan` | allowed | VPN client Internet. |

## Router Access

Router input is denied by default. These rules expose only required local router
services.

| Source | Services |
| --- | --- |
| `wan` | WireGuard UDP `51820`, DHCPv6, required ICMPv6. |
| `vlan10` | HTTPS `443`, SSH `22`, AdGuard Home UI TCP `3000`, DNS TCP/UDP `53`, DHCP UDP `68 -> 67`. |
| `vlan20` | DNS TCP/UDP `53`. |
| `vlan30` | DNS TCP/UDP `53`, DHCP UDP `68 -> 67`. |
| `vlan40` | DNS TCP/UDP `53`, DHCP UDP `68 -> 67`. |
| `vlan50` | DNS TCP/UDP `53`, DHCP UDP `68 -> 67`. |
| `vlan60` | DNS TCP/UDP `53`, DHCP UDP `68 -> 67`. |
| `vpn` | HTTPS `443`, SSH `22`, AdGuard Home UI TCP `3000`, DNS TCP/UDP `53`. |

DNS is served by AdGuard Home on the router. `dnsmasq` has `option port '0'`, so
it provides DHCP only and does not listen on port `53`.

AdGuard Home's web UI is bound to the admin gateway `10.10.0.1:3000` and is
only allowed by firewall policy from `vlan10` and `vpn`. UI authentication is
rendered from SOPS-managed credentials during firmware build.

## Management Flows

| Rule | Source | Destination | Port |
| --- | --- | --- | --- |
| `Allow-VLAN10-to-VLAN20-Proxmox-HTTPS` | `vlan10` | `vlan20` | TCP `8006` |
| `Allow-VLAN10-to-VLAN20-SSH` | `vlan10` | `vlan20` | TCP `22` |
| `Allow-VLAN10-to-VLAN30-TrueNAS-HTTPS` | `vlan10` | `vlan30` | TCP `443` |
| `Allow-VLAN10-to-VLAN30-TrueNAS-SSH` | `vlan10` | `vlan30` | TCP `22` |
| `Allow-VLAN10-to-VLAN40-TalosAPI` | `vlan10` | `vlan40` | TCP `50000` |
| `Allow-VLAN10-to-VLAN40-KubeAPI` | `vlan10` | `vlan40` | TCP `6443` |
| `Allow-VPN-to-VLAN20-Proxmox-HTTPS` | `vpn` | `vlan20` | TCP `8006` |
| `Allow-VPN-to-VLAN20-SSH` | `vpn` | `vlan20` | TCP `22` |
| `Allow-VPN-to-VLAN30-TrueNAS-HTTPS` | `vpn` | `vlan30` | TCP `443` |
| `Allow-VPN-to-VLAN30-TrueNAS-SSH` | `vpn` | `vlan30` | TCP `22` |
| `Allow-VPN-to-VLAN40-TalosAPI` | `vpn` | `vlan40` | TCP `50000` |
| `Allow-VPN-to-VLAN40-KubeAPI` | `vpn` | `vlan40` | TCP `6443` |

## Data Flows

| Rule | Source | Destination | Port | Purpose |
| --- | --- | --- | --- | --- |
| `Allow-VLAN20-to-VLAN30-NFSv4` | `vlan20` | `vlan30` | TCP `2049` | Proxmox to TrueNAS NFSv4 storage. |
| `Allow-VLAN40-to-VLAN30-NFSv4` | `vlan40` | `vlan30` | TCP `2049` | Kubernetes to TrueNAS NFSv4 storage. |

## Wireless Placement

| Radio | Network | Purpose |
| --- | --- | --- |
| 2.4 GHz | `vlan50` | Untrusted Wi-Fi. |
| 5 GHz | `vlan10` | Admin Wi-Fi. |

The 2.4 GHz SSID uses client isolation. The 5 GHz SSID is privileged because it
lands on the admin VLAN.

## Rule Naming

Allow rules use this format:

```text
Allow-<src>-to-<dest>-<proto>-<port>
```

For router input rules, use `Router` as the destination:

```text
Allow-vlan10-to-router-tcp-22
```

For WAN-exposed router services, use `WAN` as the source:

```text
Allow-wan-to-router-udp-51820
```

## Boundaries

OpenWrt enforces traffic that routes between zones. It does not normally inspect
traffic between two devices inside the same VLAN.

Use host controls for same-zone security:

- Proxmox firewall and MFA for hypervisor management.
- TrueNAS users, shares, ACLs, and service restrictions for storage.
- Talos certificates and Kubernetes RBAC for cluster access.
- Kubernetes NetworkPolicy for pod-to-pod restrictions.
