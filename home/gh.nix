{ lib, pkgs, ... }:
let
  inherit (import ./lib { inherit lib pkgs; }) mkSeedActivation;
in
{
  # Enable the gh binary but don't manage config.yml declaratively — gh needs
  # to write to it during `gh auth login` and `gh auth setup-git`. A Home
  # Manager-managed symlink into the read-only Nix store would break those
  # flows. Instead we seed a default config on first run only.
  programs.gh.enable = true;

  home.activation.seedGhConfig = mkSeedActivation {
    name = "gh-config";
    path = ".config/gh/config.yml";
    content = ''
      git_protocol: https
      prompt: enabled
    '';
  };
}
