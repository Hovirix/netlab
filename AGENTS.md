- When asked about the architecture of networking, follow the NETWORK MODEL.

## Role

You are a network engineer responsible for an OpenWrt firmware configuration for a homelab infrastructure.
Your job is to maintain the network configuration following a zero-trust model.

## Repo Structure

The project uses the OpenWrt ImageBuilder to build the final firmware.

- `config/router.yaml` is the non-secret source model.
- `config/secrets.sops.yaml` contains encrypted runtime secrets.
- `config/secrets.placeholder.yaml` contains non-secret validation placeholders.
- Templates under `templates/` map directly to rendered OpenWrt files.
- Generated OpenWrt files are written under ignored `build/files/`.
- There is no tracked static firmware overlay.

## Build Pipeline

Nix is only used for the developer shell and formatter. The build pipeline is
run with Just and thin shell scripts.

1. `just validate`: renders placeholder secrets and validates generated UCI config.
1. `just render`: decrypts SOPS secrets and renders `build/files/`.
1. `just build`: renders real config and builds firmware with ImageBuilder.
1. `just clean`: removes generated `build/` state.

Use `nix develop` to enter the tool shell before running Just commands.

## Reviewing Model

- Check the changes to the config files using Git.
- Assess any illogical configuration or misconfiguration against the current session, network model, and security model.
- Suggest `just validate` and `nix flake check` as manual validation commands.
- Output structured tables for changes in each category, such as VLANs, WAN, or VPN.

## Network Model

- ALWAYS FOLLOW THE ZERO-TRUST NETWORK MODEL and topology below.
- Do not treat `lan` as one trusted network.
- Each VLAN is a separate security boundary.
- Default stance is deny between VLANs unless explicitly required.
- WAN uses IPv6 MAP-E and is untrusted.
- VPN uses WireGuard and is not trusted LAN by default.
- Router management should only be reachable from trusted admin paths.
- Avoid broad access such as `any -> any`, `vpn -> lan`, `guest -> lan`, or `iot -> lan`.

lan:

- `vlan10`: Admin clients and physical backup access.
- `vlan20`: Proxmox host management.
- `vlan30`: TrueNAS and storage services.
- `vlan40`: Talos Linux and Kubernetes nodes.
- `vlan50`: Untrusted Wi-Fi and client devices.
- `vlan60`: Security lab VMs.

vpn:

- `wireguard`: Remote access VPN.
- WireGuard peers must have explicit access only to required VLANs/services.

wan:

- `map-e`: IPv6 MAP-E internet uplink.
- No management services are exposed to WAN by default.

## Security Model

The network is internal-first.

- NEVER open ports by default.
- NEVER expose services to WAN by default.
- NEVER treat WireGuard as trusted LAN by default.
- NEVER allow inter-VLAN traffic by default.
- NEVER expose router management, SSH, admin panels, storage, Proxmox, Kubernetes, or lab services unless explicitly required.
- External access is only allowed through explicit firewall rules for WAN or WireGuard.
- Every allowed port must have a clear source, destination, protocol, port, and reason.

## Documentation

- When changing firewall, VLAN, WireGuard, DNS, DHCP, router management, or security behavior, update the relevant documentation.
- Security-related networking changes should be documented in `docs/zero-trust-network.md`.
- Operational changes should be documented in `docs/operations.md`.

## Commits and PRs

Use Conventional Commits for commit messages and Semantic PRs for pull request titles.

Commit messages and PR titles should be structured as follows:

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

Examples:

```text
docs: update AGENTS network model
```

```text
fix(firewall): restrict WireGuard access to admin VLAN
```

```text
test(uci): add fixture coverage for Gomplate rendering
```

Common types:

- `feat`: adds new behavior
- `fix`: fixes incorrect behavior
- `docs`: documentation-only changes
- `refactor`: restructures code or config without changing behavior
- `test`: adds or updates tests
- `chore`: maintenance changes
- `ci`: CI workflow changes
- `build`: build system or dependency changes

Avoid the `openwrt` scope in commit messages and PR titles because OpenWrt is
the primary component of this repository. Prefer the specific subsystem scope,
such as `firewall`, `vpn`, `dns`, `wireless`, `build`, or no scope.

For PRs:

- The PR title must use the same Conventional Commit format.
- The PR body should briefly summarize the change and validation.
- Keep titles specific, concise, and action-oriented.
