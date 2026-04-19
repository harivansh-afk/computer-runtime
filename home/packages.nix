{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zsh
    pure-prompt
    zsh-syntax-highlighting
    zsh-autosuggestions

    fzf
    ripgrep
    fd
    eza
    bat
    zoxide

    tmux

    git
    gh
    lazygit
    delta

    jq
    curl
    htop
  ];
}
