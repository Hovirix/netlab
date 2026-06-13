{
  build-system-pkgs,
  pkgs,
  pyproject-nix,
  treefmtWrapper,
  uv2nix,
}:

let
  inherit (pkgs) lib;

  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  python = pkgs.python312;
  pythonBase = pkgs.callPackage pyproject-nix.build.packages { inherit python; };

  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  pythonSet = pythonBase.overrideScope (
    lib.composeManyExtensions [
      build-system-pkgs.overlays.wheel
      overlay
    ]
  );

  editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };
  editablePythonSet = pythonSet.overrideScope editableOverlay;
  virtualenv = editablePythonSet.mkVirtualEnv "netlab-dev-env" workspace.deps.all;
in

pkgs.mkShell {
  packages = with pkgs; [
    actionlint
    bash
    coreutils
    curl
    deadnix
    gawk
    gitMinimal
    gnumake
    go-task
    gnused
    gnutar
    openssh
    pre-commit
    qrencode
    shellcheck
    shfmt
    sops
    statix
    treefmtWrapper
    typos
    uci
    unzip
    wget
    wireguard-tools
    yamlfmt
    zstd
    uv
    virtualenv
  ];

  env = {
    UV_NO_SYNC = "1";
    UV_PYTHON = editablePythonSet.python.interpreter;
    UV_PYTHON_DOWNLOADS = "never";
  };

  shellHook = ''
    unset PYTHONPATH
    export REPO_ROOT=$(git rev-parse --show-toplevel)
  '';
}
