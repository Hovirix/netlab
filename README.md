# HX Net Lab

Network-as-Code for managing and deploying OpenWrt firmware for my [homelab](https://github.com/hovirix/homelab) network infrastructure.

## Why

As network configuration grows, managing everything directly on the router becomes impractical. All infrastructure depends on stable networking, so a safer and more repeatable workflow is required.

This repository provides a single source of truth for network configuration, enabling controlled, reproducible firmware builds and deployments.

## Features

- **Reproducible builds** – Pinned OpenWrt version with explicit target, subtarget, and profile
- **Verified ImageBuilder source** – Fetches OpenWrt ImageBuilder and checks its SHA-256
- **Secrets handling** – Decrypts SOPS files only during local build runtime
- **Template rendering** – Jinja templates are prepared for the upcoming Python renderer
- **Safe deployment** – Sysupgrade deployment will stay explicit when the build workflow returns
- **Taskfile workflow** – Taskfile currently exposes formatting, checks, and cleanup
- **Integrated dev tooling** – `nix develop`, `nix fmt`, and `nix flake check` provide tools and formatting only
- **Python dependency locking** – `uv.lock` and uv2nix provide the future Python/Jinja workflow dependencies

## Workflow

Rendering, data validation, build, and deploy commands are intentionally pending
while the Python/Jinja workflow is being prepared.

Available commands:

```bash
task fmt
task check
task clean
```

> [!WARNING]
> Sysupgrade will reboot your router and reset existing config (`sysupgrade -n`).

## Configuration & Usage

### Prerequisites

> [!NOTE]
> Future render/build commands will require readable `secrets/secrets.sops.yaml`.
> `.sops.yaml` configures encryption for SOPS-managed YAML files.
> Default secret and output paths resolve from the Git worktree root, not the
> current shell directory.

### Steps

1. Prepare configuration.
   Non-secret policy lives in `config/default.yml` and secrets live in `secrets/secrets.sops.yaml`.

1. Enter the development shell, or ensure all [dependencies](https://openwrt.org/docs/guide-user/additional-software/imagebuilder?s%5B%5D=openwrt#prerequisites) are installed:

```bash
nix develop
```

The development shell uses uv2nix to build an editable Python environment from
`pyproject.toml` and `uv.lock`. Do not use `uv run` inside the shell; Python
dependencies are provided by Nix.

3. Optional runtime overrides

```bash
ROUTER_HOST=10.10.0.1
ROUTER_USER=root
ROUTER_PORT=22
SECRETS_FILE=/path/to/secrets/secrets.sops.yaml
NETLAB_ROOT=/path/to/netlab
BUILD_OUTPUT_DIR=/path/to/output
```

4. Validate repository formatting/tooling

```bash
task check
```

Format repository files with:

```bash
task fmt
```

Encrypt or update a secret file with:

```bash
sops --encrypt --in-place secrets/secrets.sops.yaml
```

5. Build and deploy commands are pending until data validation and the Python renderer are implemented.

1. Cleanup is automatic on commit via pre-commit hook.

## Architecture

```text
flake.nix
  └─ devShells     → local uv2nix-backed tool environment

pyproject.toml / uv.lock
  └─ Python project metadata and dependency lock

Taskfile.yml
  └─ workflow      → fmt, check, clean

config/default.yml
  └─ all non-secret OpenWrt, router, network, firewall, and service config

secrets/secrets.sops.yaml
  └─ decrypted at runtime only

secrets/.sops.yaml
  └─ SOPS encryption policy

templates/imagebuilder.config.j2
  └─ Jinja ImageBuilder metadata template

templates/package-list.txt.j2
  └─ Jinja OpenWrt package list template

templates/files/*.j2
  └─ Jinja runtime file templates for the upcoming renderer

shell.nix
  └─ uv2nix development shell packages

treefmt.nix
  └─ formatter configuration

.pre-commit-config.yaml
  └─ cleanup, treefmt, and lint hooks

.github/workflows/validate-uci.yml
  └─ repository validation
```

## CI/CD

- `validate-uci.yml` – Runs `nix flake check`

## Local pre-commit setup

Install and enable hooks once per clone:

```bash
nix develop --command pre-commit install
```

Run all hooks manually:

```bash
nix develop --command pre-commit run --all-files
```
