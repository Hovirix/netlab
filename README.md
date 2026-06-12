# HX Net Lab

Network-as-Code for managing and deploying OpenWrt firmware for my [homelab](https://github.com/hovirix/homelab) network infrastructure.

## Why

As network configuration grows, managing everything directly on the router becomes impractical. All infrastructure depends on stable networking, so a safer and more repeatable workflow is required.

This repository provides a single source of truth for network configuration, enabling controlled, reproducible firmware builds and deployments.

## Features

- **Reproducible builds** – Pinned OpenWrt version with explicit target, subtarget, and profile
- **Verified ImageBuilder source** – Fetches OpenWrt ImageBuilder and checks its SHA-256
- **Secrets handling** – Decrypts SOPS files only during local build runtime
- **Template rendering** – Generates UCI configs using Gomplate at build time
- **Safe deployment** – Keeps sysupgrade as an explicit manual step
- **Taskfile workflow** – Plain shell scripts provide the render, test, build, and deploy path
- **Automated updates** – Weekly check for new OpenWrt releases with PR + issue

## Workflow

```text
apply (check-update -> test -> render -> build -> deploy)
```

1. **check-update** – Warn if a newer OpenWrt release exists
1. **test** – Render fixtures and validate UCI config
1. **render** – Render secrets locally into `build/staged-files/`
1. **build** – Build the firmware image with OpenWrt ImageBuilder
1. **deploy** – Upload firmware, run `sysupgrade -n`, and reboot

> [!WARNING]
> Sysupgrade will reboot your router and reset existing config (`sysupgrade -n`).

## Configuration & Usage

### Prerequisites

> [!NOTE]
> `task build` requires readable SOPS secret files in `secrets/`.
> `.sops.yaml` configures encryption for `secrets/*.sops.yaml`.
> Default secret and output paths resolve from the Git worktree root, not the
> current shell directory.

### Steps

1. Prepare configuration.
   Non-secret policy lives in `config/*.yaml` and secrets live in `secrets/*.sops.yaml`.

1. Enter the development shell, or ensure all [dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder?s%5B%5D=openwrt#prerequisites) are installed:

```bash
nix develop
```

3. Optional runtime overrides

```bash
ROUTER_HOST=10.10.0.1
ROUTER_USER=root
ROUTER_PORT=22
NETWORK_SECRET=/path/to/network.sops.yaml
WIRELESS_SECRET=/path/to/wireless.sops.yaml
ADGUARDHOME_SECRET=/path/to/adguardhome.sops.yaml
NETLAB_ROOT=/path/to/netlab
BUILD_OUTPUT_DIR=/path/to/output
```

4. Validate and build firmware

```bash
task test
task build
```

Encrypt or update a secret file with:

```bash
sops --encrypt --in-place secrets/adguardhome.sops.yaml
```

5. Deploy firmware

```bash
task deploy
```

Or run the full pipeline with one command:

```bash
task apply
```

6. Cleanup is automatic on commit via pre-commit hook (generated artifacts).

## Architecture

```text
flake.nix
  └─ devShells     → optional local tool environment only

Taskfile.yml
  └─ workflow      → test, render, build, deploy, apply

config/*.yaml
  └─ non-secret network, DHCP, and firewall policy

config/openwrt.env
  └─ OpenWrt target, package, ImageBuilder, and router deploy settings

scripts/*.sh
  └─ plain shell implementation of each workflow step

secrets/*.sops.yaml
  └─ decrypted at runtime only

templates/*.tmpl
  └─ rendered into build/staged-files/etc/*

files/*
  └─ static files copied into build/staged-files/

build/staged-files/*
  └─ rendered firmware file tree passed to ImageBuilder

build/output/*
  └─ firmware artifacts

tests/fixtures/*
  └─ non-secret datasource fixtures for syntax checks

.pre-commit-config.yaml
  └─ cleanup, formatting, and lint hooks

.github/workflows/openwrt-update.yml
  └─ scheduled update detection and PR/issue creation
```

## CI/CD

- `validate-uci.yml` – Runs `task test` in the development shell
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
