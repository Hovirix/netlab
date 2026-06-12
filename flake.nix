{
  description = "HX Net Lab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      devshell = import ./devshell.nix { inherit pkgs; };
    in
    {
      devShells.${system} = devshell.devShells;
    };
}
