## Sources Of Truth

- `config/router.yaml` is the non-secret desired-state model: build metadata, VLANs, switch ports, firewall policy, DHCP, wireless, and services.
- `config/secrets.sops.yaml` is encrypted runtime input. Decrypt it only through the renderer; decrypted data belongs only in ignored `build/generated/`.
- `templates/` plus `scripts/render.sh` define the entire generated OpenWrt overlay in ignored `build/files/`; there is no static overlay to edit.
- Prefer the templates and scripts over README prose when they differ.

## Commands

- `task check` runs the non-secret, focused workflow check: `actionlint`.
- `nix flake check --print-build-logs` is the CI-equivalent check; `nix fmt` is also the pre-commit formatter.
- `task build` decrypts and renders secrets, validates UCI syntax for `network`, `dhcp`, `firewall`, `wireless`, and `dropbear`, verifies the ImageBuilder hash, then writes firmware to `build/artifacts/`.
- `task update` fetches and verifies OpenWrt's signed checksum manifest, changes only the version and ImageBuilder hash in `config/router.yaml`, and writes ignored release notes/downloads under `build/`. It does not decrypt runtime secrets.
- `task deploy` builds first, then uploads the matching sysupgrade image with `scp -O` and executes `sysupgrade -n`; it resets router configuration and reboots the device.

## Security Model

- Every VLAN and WireGuard are separate firewall zones. Router input and inter-zone forwarding are default-deny; add only narrow, documented flows in `config/router.yaml`.
- Model firewall permits with a concrete source, destination, protocol, port, and reason. Do not introduce broad VLAN or VPN forwarding.
- WAN is IPv6 MAP-E and untrusted. Do not expose router management or internal services to WAN beyond the explicit WireGuard listener.
- Template zone names are `vlan<ID>`, not the semantic keys from `router.yaml`; use the model keys in rules and template lookups.
- `wan: true` produces `vlan<ID> -> wan`; `vpn -> wan` is unconditional. `cyberlab` intentionally has no WAN forwarding.
- DNS input allows are generated for every VLAN; DHCP input allows and pools are generated only for VLANs with `dhcp: true`.
- `dnsmasq` is not the DNS listener (`port: 0`); AdGuard Home binds DNS port 53 and its UI is `10.10.0.1:3000`.

## Topology And Recovery

- Preserve management recovery access: untagged `lan5` is `vlan10`; `lan4` is intentionally unused. Router SSH/HTTPS and AdGuard UI are available from management and VPN; WAN UDP 51820 is WireGuard.
- `lan1`/`lan2` tag Proxmox, homelab, kubelab, and cyberlab; `lan3` is untagged TrueNAS. Client Wi-Fi maps to `vlan70` with isolation; admin Wi-Fi maps to `vlan10`.
- Before deployment, inspect generated `build/files/etc/config/*`. `build/` may hold decrypted secrets, ImageBuilder downloads, and firmware, and must never be committed.

## Automation

- CI is deliberately non-secret: it runs only `nix flake check`. Releases contain tags and changelogs, not firmware.
- The weekly update workflow opens `chore/update-openwrt` PRs limited to `config/router.yaml`; locally build and validate an update before deploying it.
- Release Please uses Conventional Commits. Prefer scopes such as `firewall`, `vpn`, `dns`, `wireless`, `build`, or `deps`, not `openwrt`.
