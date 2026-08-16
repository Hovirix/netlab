# OpenWrt Operations

This repo uses Gomplate templates to render final OpenWrt config files into
`build/files`. Nix is only used to provide the local tool shell.

## Commands

| Command | Purpose |
| --- | --- |
| `nix develop` | Enter the reproducible tool shell. |
| `task validate` | Decrypt SOPS secrets and validate generated UCI. |
| `task render` | Decrypt SOPS secrets and render `build/files`. |
| `task build` | Render real config and build firmware with ImageBuilder. |
| `task update` | Update the OpenWrt release and pinned ImageBuilder hash without decrypting secrets. |
| `task deploy` | Upload the built sysupgrade image with `scp -O` and run `sysupgrade -n`. |
| `task clean` | Remove `build/`. |

## CI And Updates

GitHub Actions are intentionally non-secret. CI must not receive SOPS keys,
decrypt `config/secrets.sops.yaml`, render the real runtime overlay, build
firmware, or deploy to the router.

| Automation | Scope | Secrets Required |
| --- | --- | --- |
| `check.yml` | Runs `nix flake check` for formatting and Nix evaluation. | no |
| Renovate | Opens PRs for `flake.lock` input updates and GitHub Actions versions. | no |
| `update-openwrt.yml` | Opens PRs for `build.openwrt_version` and `build.imagebuilder_hash`. | no |

OpenWrt update PRs only update public release metadata in `config/router.yaml`.
Review and validate them locally before merge or deployment:

```bash
task validate
task build
```

## Generated Files

| File | Role |
| --- | --- |
| `build/files/etc/config/network` | Interfaces, bridge VLANs, WAN MAP-E, and WireGuard. |
| `build/files/etc/config/dhcp` | DHCP service and DHCP-provided DNS options. |
| `build/files/etc/config/firewall` | Zone policies, forwarding, and explicit allow rules. |
| `build/files/etc/config/wireless` | Wi-Fi radios and SSID network mapping. |
| `build/files/etc/adguardhome/adguardhome.yaml` | AdGuard Home runtime config. |

## Build State

All mutable build state is ignored under `build/`:

| Directory | Purpose |
| --- | --- |
| `build/generated` | Decrypted temporary YAML secret files. |
| `build/files` | Final ImageBuilder overlay. |
| `build/downloads` | Downloaded ImageBuilder archive. |
| `build/imagebuilder` | Unpacked ImageBuilder tree. |
| `build/artifacts` | Firmware output. |

## Deployment Safety

Before flashing a generated image, review `build/files/etc/config/*` and verify
these access paths remain present:

| Path | Required Before Hardening |
| --- | --- |
| Physical backup | `lan5` provides untagged access to `vlan10`. |
| Mini PC trunks | `lan1` and `lan2` provide tagged access to VLANs `20`, `40`, `50`, and `60`. |
| TrueNAS access | `lan3` provides untagged DHCP access to `vlan30`. |
| Local management | Management client can get DHCP on `vlan10`. |
| Router SSH | `vlan10 -> router` TCP `22` works. |
| Router HTTPS | `vlan10 -> router` TCP `443` works if LuCI or HTTPS admin is used. |
| AdGuard Home UI | `vlan10 -> router` TCP `3000` works. |
| WireGuard | WAN UDP `51820` reaches the router. |

`task deploy` reads the target from `config/router.yaml`, uploads the matching
sysupgrade artifact from `build/artifacts` to `/tmp` with `scp -O`, then runs
`sysupgrade -n` over SSH. Build first with `task build`.

After deploying to the router, validate firewall syntax before restarting it:

```bash
fw4 check
```

Restart firewall only after syntax validates:

```bash
service firewall restart
```

## Change Checklist

When adding a VLAN:

1. Add the VLAN in `config/router.yaml`.
1. Add bridge membership in `config/router.yaml`.
1. Add DHCP behavior through the VLAN `dhcp` flag.
1. Confirm `templates/firewall.tmpl` derives a separate zone.
1. Add only explicit forwarding/rules required by the zero-trust model.
1. Run `task validate`.
1. Review generated `build/files/etc/config/*`.

When adding an allow rule:

1. Add source, destination, protocol, port, and reason in `config/router.yaml`.
1. Avoid broad `any -> any`, `vpn -> lan`, `guest -> lan`, or `iot -> lan` rules.
1. Run `task validate`.
1. Review the generated firewall rule in `build/files/etc/config/firewall`.

When adding a DHCP reservation:

1. Add the host under `dhcp.static_leases` in `config/router.yaml` with `name`, `vlan`, `mac`, and `ip`.
1. Keep the reserved IP inside the VLAN subnet and outside the dynamic DHCP pool.
1. Run `task validate`.
1. Review the generated host entry in `build/files/etc/config/dhcp`.
