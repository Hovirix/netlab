## Role

Maintain this repo as an OpenWrt homelab router firmware configuration using a zero-trust network model.

## Sources Of Truth

- `config/router.yaml` is the non-secret model for build metadata, VLANs, switch ports, firewall policy, DHCP, wireless, AdGuard Home, Dropbear, cron, and services.
- `config/secrets.sops.yaml` is encrypted runtime input; do not write decrypted secrets outside ignored `build/generated/`.
- `templates/*.tmpl` render one-for-one into OpenWrt files under ignored `build/files/`; there is no tracked static overlay.
- Trust executable config and scripts over prose if docs drift.

## Commands

- Enter the tool shell first when dependencies may be missing: `nix develop`.
- `task build` runs the internal `render` and `validate` steps (decrypting SOPS secrets, rendering `build/files/`, and running UCI validation for `network`, `dhcp`, `firewall`, `wireless`, and `dropbear`), then builds firmware with ImageBuilder; firmware lands in `build/artifacts/`.
- `task update` updates only `build.openwrt_version` and `build.imagebuilder_hash` in `config/router.yaml`; it does not decrypt secrets.
- `task deploy` requires `task build` first, uploads the matching sysupgrade image with `scp -O`, then runs `sysupgrade -n` and resets router config.
- `nix flake check --print-build-logs` is the CI check; `nix fmt` is the pre-commit formatter.

## Build And CI Constraints

- Nix provides the dev shell and formatter only; firmware build logic lives in `Taskfile.yml` and `scripts/`.
- `build/` can contain decrypted secrets, rendered OpenWrt files, downloaded ImageBuilder archives, unpacked builders, and firmware artifacts; it is ignored and should not be committed.
- GitHub Actions are intentionally non-secret: CI runs only `nix flake check`; it must not decrypt SOPS secrets, render real runtime config, build firmware, or deploy.
- OpenWrt update automation opens `chore/build` PRs for public release metadata only; validate and build locally before deployment.

## Zero-Trust Network Model

- Do not treat `lan` as trusted; every VLAN is a separate firewall zone and security boundary.
- Default stance is deny/reject between VLANs, VPN, and router input unless an explicit rule is required.
- WAN is IPv6 MAP-E and untrusted; never expose router management or internal services to WAN by default.
- WireGuard is its own `vpn` zone, not trusted LAN; peers need explicit access only to required VLANs/services.
- Each allow rule must have a clear source, destination, protocol, destination port, and reason in `config/router.yaml`.
- Avoid broad access such as `any -> any`, `vpn -> lan`, `guest -> lan`, or `iot -> lan`.

## Current Topology

- `vlan10` management: DHCP yes, WAN yes, physical backup/management access on untagged `lan5`, 5 GHz admin Wi-Fi.
- `vlan20` Proxmox: DHCP no, WAN yes, tagged on `lan1` and `lan2`.
- `vlan30` TrueNAS: DHCP yes, WAN yes, untagged `lan3`.
- `vlan40` homelab: DHCP yes, WAN yes, tagged on `lan1` and `lan2`; prod Docker Swarm nodes (static leases `swarm-01/02/03`).
- `vlan50` kubelab: DHCP yes, WAN yes, tagged on `lan1` and `lan2`; Kubernetes/Talos workloads.
- `vlan60` cyberlab: DHCP yes, WAN no, tagged on `lan1` and `lan2`; security lab.
- `vlan70` clients: DHCP yes, WAN yes, 2.4 GHz Wi-Fi with client isolation, no switch ports.
- `lan4` is intentionally unused.

## Template Behavior To Preserve

- Firewall zone names render as `vlan<ID>` even though model keys are semantic names like `management`, `truenas`, and `homelab`.
- VLANs with `wan: true` get `vlan<ID> -> wan` forwarding; `vpn -> wan` is always rendered; lab currently has no WAN forwarding.
- DNS router-input allow rules are rendered for every VLAN; DHCP router-input allow rules are rendered only for VLANs with `dhcp: true`.
- `dnsmasq` has `port: 0`; AdGuard Home is the DNS listener on port `53`, with UI bound to `10.10.0.1:3000`.
- Wireless SSIDs use SOPS-provided shared name/passwords plus model suffixes; `wireless.interfaces[].network` maps to a VLAN model key.

## Documentation

- Update `docs/zero-trust-network.md` when changing firewall, VLAN, WireGuard, DNS, DHCP, router management, wireless placement, or security behavior.
- Update `docs/operations.md` when changing build, validation, update, deployment, or operator workflows.
- Before flashing, review generated `build/files/etc/config/*` and preserve documented access paths: `lan5` management, router SSH/HTTPS from `vlan10`, AdGuard UI from `vlan10`, and WAN UDP `51820` for WireGuard.

## Commits And PRs

- Use Conventional Commits and Semantic PR titles, for example `fix(firewall): restrict WireGuard access to management VLAN`.
- Avoid `openwrt` as a scope because it is the whole repo; prefer scopes like `firewall`, `vpn`, `dns`, `wireless`, `build`, `deps`, or no scope.
