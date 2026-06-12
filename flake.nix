{
  description = "HX Net Lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      treefmtEval = treefmt-nix.lib.evalModule pkgs {
        projectRootFile = "flake.nix";

        programs = {
          deadnix.enable = true;
          mdformat.enable = true;
          nixfmt.enable = true;
          shfmt.enable = true;
          statix.enable = true;
          taplo.enable = true;
          typos = {
            enable = true;
            excludes = [ "secrets.sops.yaml" ];
          };
          yamlfmt = {
            enable = true;
            excludes = [ "secrets.sops.yaml" ];
            settings.formatter = {
              type = "basic";
              retain_line_breaks_single = true;
            };
          };
        };
      };
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system}.formatting = treefmtEval.config.build.check self;

      devShells.${system}.default = pkgs.mkShell {
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
          treefmtEval.config.build.wrapper
          uci
          unzip
          wget
          wireguard-tools
          yamlfmt
          zstd
        ];
      };
    };
}
