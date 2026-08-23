{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    mdformat = {
      enable = true;
      excludes = [ "CHANGELOG.md" ];
    };
    nixfmt.enable = true;
    shfmt = {
      enable = true;
      indent_size = 2;
    };
    ruff.enable = true;
    statix.enable = true;
    taplo.enable = true;
    typos = {
      enable = true;
      excludes = [
        "config/*.sops.yaml"
        "keys/*.asc"
      ];
    };
    yamlfmt = {
      enable = true;
      excludes = [ "config/*.sops.yaml" ];
      settings.formatter = {
        type = "basic";
        retain_line_breaks_single = true;
      };
    };
  };
}
