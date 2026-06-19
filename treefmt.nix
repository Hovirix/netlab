{
  projectRootFile = "flake.nix";

  programs = {
    deadnix.enable = true;
    mdformat.enable = true;
    nixfmt.enable = true;
    shfmt = {
      enable = true;
      indent_size = 2;
    };
    statix.enable = true;
    taplo.enable = true;
    typos = {
      enable = true;
      excludes = [ "config/*.sops.yaml" ];
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
