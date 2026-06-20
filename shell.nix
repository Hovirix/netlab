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
    sops
    uci
    unzip
    wget
    zstd
  ];
}
