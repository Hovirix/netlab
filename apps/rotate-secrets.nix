{ pkgs, ... }:
let
  python = pkgs.python3.withPackages (pythonPkgs: [ pythonPkgs.ruamel-yaml ]);
  appRotateSecrets = pkgs.writeShellApplication {
    name = "rotate-secrets";
    runtimeInputs = [
      python
      pkgs.gitMinimal
      pkgs.qrencode
      pkgs.sops
      pkgs.wireguard-tools
    ];
    text = ''
      set -euo pipefail

      exec python ${../scripts/rotate-wireguard-secrets.py} "$@"
    '';
  };
in
{
  apps.rotate-secrets = {
    type = "app";
    program = "${appRotateSecrets}/bin/rotate-secrets";
    meta.description = "Rotate WireGuard secrets in SOPS files";
  };
}
