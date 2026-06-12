{ pkgs, ... }:
{
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      actionlint
      bash
      coreutils
      curl
      gawk
      gitMinimal
      gnumake
      gomplate
      go-task
      gnused
      gnutar
      openssh
      pre-commit
      qrencode
      (python3.withPackages (pythonPackages: [ pythonPackages.ruamel-yaml ]))
      shellcheck
      shfmt
      sops
      uci
      unzip
      wget
      wireguard-tools
      yamlfmt
      zstd
    ];
  };
}
