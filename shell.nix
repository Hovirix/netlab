{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    curl
    gomplate
    gnumake
    gnutar
    just
    pre-commit
    sops
    uci
    zstd
  ];
}
