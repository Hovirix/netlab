{
  projectRootFile = "flake.nix";

  programs = {
    mdformat.enable = true;
    nixfmt.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
    yamlfmt = {
      enable = true;
      excludes = [
        "secrets.sops.yaml"
        "secrets/*.sops.yaml"
      ];
      settings.formatter = {
        type = "basic";
        retain_line_breaks_single = true;
      };
    };
  };
}
