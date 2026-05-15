{ pkgs, ... }:
let
  repoRoot = toString ../.;
  appApply = pkgs.writeShellApplication {
    name = "apply";
    runtimeInputs = [
      pkgs.nix
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail

      printf 'Step 1/4: check-update\n'
      if ! nix run '${repoRoot}#check-update'; then
        printf 'Warning: check-update failed, continuing\n' >&2
      fi

      printf 'Step 2/4: flake check\n'
      nix flake check '${repoRoot}'

      printf 'Step 3/4: build\n'
      nix run '${repoRoot}#build'

      printf 'Step 4/4: sysupgrade\n'
      nix run '${repoRoot}#sysupgrade'
    '';
  };
in
{
  apps.apply = {
    type = "app";
    program = "${appApply}/bin/apply";
  };
}
