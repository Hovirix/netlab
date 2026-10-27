{
  description = "HX Net Lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          trivy
          squashfsTools
          curl
          actionlint
          deadnix
          gnupg
          gomplate
          gnumake
          gnutar
          go-task
          mdformat
          nixfmt
          openssh
          pre-commit
          python3
          ruff
          shellcheck
          shfmt
          sops
          statix
          taplo
          treefmt
          typos
          uci
          unzip
          yq-go
          yamlfmt
          wget
          zstd
        ];
      };
    };
}
