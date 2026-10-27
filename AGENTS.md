# Context

HX Net Lab is an infrastructure-as-code project that builds reproducible, security-focused OpenWrt firmware for a segmented homelab network using Nix, Task, Gomplate, and SOPS.

## Architecture

- `config/router.yaml` defines the non-secret network configuration.
- `config/secrets.sops.yaml` contains SOPS-encrypted secrets.
- `templates/` defines the generated OpenWrt filesystem.
- `scripts/` implements rendering, building, updating, and deployment.
- `Taskfile.yml` orchestrates workflows.
- `flake.nix` defines the reproducible development environment.
- `build/` contains generated files and artifacts; never commit it.

Configuration and templates are the sources of truth. Never edit generated files directly.

## Security

- Preserve default-deny firewall policies and network segmentation.
- Allow only explicitly authorized traffic between VLANs.
- Preserve management access through VLAN 10 and WireGuard.
- Keep the Iliad DHCPv6, MAP-E, and IPv6 default-route configuration functional.
- Never deploy firmware without explicit approval.
- Treat deployment as destructive: `sysupgrade -n` resets existing router configuration.

## Conventions

- Prefer minimal, maintainable changes.
- Reuse existing tools before introducing dependencies.
- Keep orchestration in Taskfile and implementation in scripts.
- Avoid duplicated configuration and unnecessary abstractions.
- Use Conventional Commits.
