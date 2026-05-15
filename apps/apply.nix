{ pkgs, ... }:
let
  appApply = pkgs.writeShellApplication {
    name = "apply";
    runtimeInputs = [
      pkgs.nix
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      printf 'Step 1/4: check-update\n'
      if ! nix run .#check-update; then
        printf 'Warning: check-update failed, continuing\n' >&2
      fi

      printf 'Step 2/4: flake check\n'
      nix flake check

      printf 'Step 3/4: build\n'
      nix run .#build

      printf 'Step 4/4: sysupgrade\n'
      nix run .#sysupgrade
    '';
  };
in
{
  apps.apply = {
    type = "app";
    program = "${appApply}/bin/apply";
    meta.description = "Check, build, and deploy OpenWrt firmware";
  };
}
