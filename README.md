# HX Net Lab

Network-as-code for building OpenWrt firmware for the homelab router.

## Stack

```text
YAML       non-secret model
SOPS       encrypted runtime secrets
Gomplate   final OpenWrt file rendering
Bash       pipeline glue only
Just       local command runner
ImageBuilder firmware build
Nix        dev shell only
```

## Workflow

Enter the tool shell:

```bash
nix develop
```

Validate with encrypted secrets:

```bash
just validate
```

Render real SOPS-backed config into `build/files`:

```bash
just render
```

Build firmware into `build/artifacts`:

```bash
just build
```

Deploy the built sysupgrade image to the configured router:

```bash
just deploy
```

Clean generated state:

```bash
just clean
```

## Layout

```text
config/router.yaml          non-secret source model
config/secrets.sops.yaml    encrypted runtime secrets
templates/                  one template per rendered OpenWrt file
scripts/                    thin render/validate/build glue
build/                      ignored generated output
```

Generated OpenWrt files are written only under `build/files/`.
There is no tracked static firmware overlay.
