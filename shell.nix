{ pkgs }:

pkgs.mkShell {
  packages = with pkgs; [
    curl
    actionlint
    gnupg
    gomplate
    gnumake
    gnutar
    go-task
    openssh
    pre-commit
    python3
    sops
    uci
    yq-go
    zstd
  ];
}
