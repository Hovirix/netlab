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
      config = import ./config.nix;
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;

      moduleArgs = {
        inherit pkgs config;
        treefmtCheck = treefmtEval.config.build.check self;
      };

      modules = map (module: import module moduleArgs) [
        ./apps/apply.nix
        ./apps/build.nix
        ./apps/check-update.nix
        ./apps/deploy.nix
        ./apps/rotate-secrets.nix
        ./devshell.nix
        ./apps/test.nix
      ];

      mergeModule = acc: module: {
        apps = acc.apps // (module.apps or { });
        checks = acc.checks // (module.checks or { });
        devShells = acc.devShells // (module.devShells or { });
      };

      merged = builtins.foldl' mergeModule {
        apps = { };
        checks = { };
        devShells = { };
      } modules;
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;
      apps.${system} = merged.apps;
      checks.${system} = merged.checks;
      devShells.${system} = merged.devShells;
    };
}
