{ pkgs, treefmtWrapper }:

pkgs.mkShell {
  packages = with pkgs; [
    actionlint
    bash
    coreutils
    curl
    gawk
    gitMinimal
    gnumake
    go-task
    gnused
    gnutar
    openssh
    pre-commit
    qrencode
    (python3.withPackages (pythonPackages: [
      pythonPackages.httpx
      pythonPackages.jinja2
      pythonPackages.pydantic
      pythonPackages.pydantic-settings
      pythonPackages.rich
      pythonPackages.ruamel-yaml
      pythonPackages.typer
    ]))
    shellcheck
    shfmt
    sops
    treefmtWrapper
    uci
    unzip
    wget
    wireguard-tools
    yamlfmt
    zstd
  ];
}
