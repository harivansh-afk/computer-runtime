{ lib, pkgs, ... }:
let
  inherit (import ./lib { inherit lib pkgs; }) mkSeedActivation;
in
{
  # Enable the lazygit binary but don't manage config.yml declaratively.
  # lazygit needs to rewrite it during config migrations (e.g. the git.paging
  # → git.pagers rename), which EPERMs when the file is a symlink into the
  # read-only Nix store. Seed a writable copy on first run instead.
  programs.lazygit.enable = true;

  home.activation.seedLazygitConfig = mkSeedActivation {
    name = "lazygit-config";
    path = ".config/lazygit/config.yml";
    content = ''
      gui:
        showFileTree: true
        theme:
          activeBorderColor:
            - "#9ece6a"
            - bold
          inactiveBorderColor:
            - "#565f89"
      git:
        pagers:
          colorArg: always
          pager: "delta --paging=never"
    '';
  };
}
