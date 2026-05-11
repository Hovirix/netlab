# HX Net Lab

Network-as-Code for managing and deploying OpenWrt firmware for my [homelab](https://github.com/hovirix/homelab) network infrastructure.

## Why

As network configuration grows, managing everything directly on the router becomes impractical. All infrastructure depends on stable networking, so a safer and more repeatable workflow is required.

This repository provides a single source of truth for network configuration, enabling controlled, reproducible firmware builds and deployments.

## Features

- **Reproducible builds** – Pinned OpenWrt version with explicit target, subtarget, and profile
- **Verified downloads** – Validates ImageBuilder checksum before extraction
- **Secrets handling** – Decrypts SOPS files only at render time
- **Template rendering** – Generates UCI configs using Gomplate
- **Safe deployment** – Validates configuration with UCI
- **Pre-commit quality gates** – Unified local formatting and linting before commits
- **Automated updates** – Weekly check for new OpenWrt releases with PR + issue

## Workflow

```text
render → check → setup → build → sysupgrade
```

1. **render** – Decrypt secrets and generate configs
1. **check** – Validate rendered configuration
1. **setup** – Download and verify ImageBuilder
1. **build** – Build firmware image
1. **sysupgrade** – Flash router and reboot

> [!WARNING]
> Sysupgrade will reboot your router.

## Configuration & Usage

### Prerequisites

> [!NOTE]
> If you do not manage secrets or provision them at runtime, remove `render` from the Taskfile.

### Steps

1. Prepare configuration.
   Files under `openwrt/files/` are copied into `/etc/` in the final image.

1. Enter the development shell, or ensure all [dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder?s%5B%5D=openwrt#prerequisites) are installed:

```bash
nix develop
```

3. Configure environment

```yaml
env:
  OPENWRT_VERSION: '25.12.3'
  OPENWRT_TARGET: mediatek
  OPENWRT_SUBTARGET: filogic
  OPENWRT_PROFILE: glinet_gl-mt6000
  OPENWRT_PACKAGES: 'adguardhome irqbalance map tailscale'
  KEEP_ARCHIVE: '1'
  ROUTER_HOST: 10.10.0.1
  ROUTER_USER: root
  ROUTER_PORT: '22'
```

4. Build firmware (runs render + check + setup automatically)

```bash
task build
```

5. Deploy firmware

```bash
task sysupgrade
```

## Architecture

```text
Taskfile.yml
  ├─ check         → openwrt/scripts/check.sh
  ├─ render        → openwrt/scripts/render.sh
  ├─ setup         → openwrt/scripts/setup.sh
  ├─ build         → openwrt/scripts/build.sh
  ├─ sysupgrade    → openwrt/scripts/sysupgrade.sh
  └─ check-update  → openwrt/scripts/check-update.sh

openwrt/scripts/common.sh
  └─ shared configuration, host detection, paths, command checks

secrets/*.sops.yaml
  └─ decrypted at runtime only

openwrt/templates/*.tmpl
  └─ rendered into openwrt/files/config/*

openwrt/files/*
  └─ included in firmware (/etc/* on device)

.pre-commit-config.yaml
  └─ formatting and lint hooks

.github/workflows/openwrt-update.yml
  └─ scheduled update detection and PR/issue creation
```

## CI/CD

- `validate-uci.yml` – Renders template fixtures and validates UCI syntax
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
