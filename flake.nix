{
  description = "HX Net Lab dev shell";

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
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;

      checks.${system} = {
        formatting = treefmtEval.config.build.check self;
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            uci
            actionlint
            shellcheck
            bash-language-server
            go-task
            pre-commit
            treefmt
            sops
            shfmt
            wget
            gnumake
            gomplate
            gzip
            unzip
            python3
            python3Packages.distutils
          ];
        };
      };
    };
}
