{ pkgs, ... }:
{
  devShells.default = pkgs.mkShell {
    packages = with pkgs; [
      actionlint
      pre-commit
      treefmt
      sops
      gomplate
      uci
      curl
    ];
  };
}
