# HX Net Lab

Network-as-Code for managing and deploying OpenWrt firmware for my [homelab](https://github.com/hovirix/homelab) network infrastructure.

## Why

As network configuration grows, managing everything directly on the router becomes impractical. All infrastructure depends on stable networking, so a safer and more repeatable workflow is required.

This repository provides a single source of truth for network configuration, enabling controlled, reproducible firmware builds and deployments.

## Features

- **Reproducible builds** – Pinned OpenWrt version with explicit target, subtarget, and profile
- **Verified ImageBuilder source** – Fetches OpenWrt ImageBuilder with fixed Nix hash
- **Secrets handling** – Decrypts SOPS files only during local build runtime
- **Template rendering** – Generates UCI configs using Gomplate at build time
- **Safe deployment** – Keeps sysupgrade as an explicit manual step
- **Pre-commit quality gates** – Unified local formatting and linting before commits
- **Automated updates** – Weekly check for new OpenWrt releases with PR + issue

## Workflow

```text
apply (check-update -> check -> build -> sysupgrade)
```

1. **check-update** – Warn if a newer OpenWrt release exists
1. **flake check** – Validate formatting and fixture-based UCI rendering
1. **build** – Render secrets locally and build firmware image
1. **sysupgrade** – Flash router and reboot

> [!WARNING]
> Sysupgrade will reboot your router and reset existing config (`sysupgrade -n`).

## Configuration & Usage

### Prerequisites

> [!NOTE]
> `nix run .#build` requires readable SOPS secret files in `secrets/`.

### Steps

1. Prepare configuration.
   Files under `files/` are copied into `/etc/` in the final image.

1. Enter the development shell, or ensure all [dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder?s%5B%5D=openwrt#prerequisites) are installed:

```bash
nix develop
```

3. Optional runtime overrides

```yaml
env:
  ROUTER_HOST: 10.10.0.1
  ROUTER_USER: root
  ROUTER_PORT: '22'
  NETWORK_SECRET: /path/to/network.sops.yaml
  WIRELESS_SECRET: /path/to/wireless.sops.yaml
```

4. Build firmware

```bash
nix flake check
nix run .#build
```

5. Deploy firmware

```bash
nix run .#sysupgrade
```

Or run the full pipeline with one command:

```bash
nix run .#apply
```

6. Cleanup is automatic on commit via pre-commit hook (generated artifacts).

## Architecture

```text
flake.nix
  ├─ apps          → apps/build.nix
  └─ checks        → apps/test.nix

apps/build.nix
  ├─ build         → render secrets + build firmware
  └─ fetchurl      → pinned OpenWrt ImageBuilder source

apps/deploy.nix
  └─ sysupgrade    → deploy image to router

apps/check-update.nix
  └─ check-update  → detect new OpenWrt release

apps/apply.nix
  └─ apply         → check-update -> check -> build -> sysupgrade

apps/test.nix
  ├─ formatting    → treefmt-nix
  └─ uci           → fixture render + UCI syntax validation

secrets/*.sops.yaml
  └─ decrypted at runtime only

templates/*.tmpl
  └─ rendered into files/etc/config/{network,wireless}

files/*
  └─ included in firmware (/etc/* on device)

tests/fixtures/*
  └─ non-secret datasource fixtures for syntax checks

.pre-commit-config.yaml
  └─ cleanup, formatting, and lint hooks

.github/workflows/openwrt-update.yml
  └─ scheduled update detection and PR/issue creation
```

## CI/CD

- `validate-uci.yml` – Runs `nix flake check` (formatting + UCI validation)
- `openwrt-update.yml` – Weekly OpenWrt release check with automated PR + issue

## Local pre-commit setup

Install and enable hooks once per clone:

```bash
nix develop --command pre-commit install
```

Run all hooks manually:

```bash
nix develop --command pre-commit run --all-files
```
