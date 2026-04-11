{
  description = "HX Net Lab dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system} = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            uci
            shellcheck
            bash-language-server
            go-task
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
