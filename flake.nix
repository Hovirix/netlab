{
  description = "HX Net Lab";

  inputs = {

    build-system-pkgs = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
        uv2nix.follows = "uv2nix";
      };
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        pyproject-nix.follows = "pyproject-nix";
      };
    };
  };

  outputs =
    {
      build-system-pkgs,
      nixpkgs,
      pyproject-nix,
      treefmt-nix,
      uv2nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;

      devShells.${system}.default = import ./shell.nix {
        inherit build-system-pkgs pyproject-nix uv2nix;
        inherit pkgs;
      };
    };
}
