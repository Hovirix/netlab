{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    curl
    gomplate
    gnumake
    gnutar
    just
    openssh
    pre-commit
    python3
    sops
    uci
    unzip
    wget
    zstd
  ];
}
