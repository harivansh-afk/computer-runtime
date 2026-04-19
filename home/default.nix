{ username, lib, ... }:
{
  imports = [
    ./packages.nix
    ./aliases.nix
    ./zsh.nix
    ./prompt.nix
    ./nvim.nix
    ./tmux.nix
    ./git.nix
    ./gh.nix
    ./fzf.nix
    ./bat.nix
    ./eza.nix
    ./lazygit.nix
    ./ssh.nix
    ./skills.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
  targets.genericLinux.enable = true;

  # targets.genericLinux drags in a GPU-driver probe that pulls mesa (~500MB)
  # into the store on activation. These are headless agent boxes — no GPU,
  # nothing to probe.
  home.activation.checkExistingGpuDrivers = lib.mkForce "";

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
