{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    # Keep .zshrc / .zshenv at $HOME rather than under $XDG_CONFIG_HOME. Some
    # tooling we rely on (Claude Code, Codex CLI, GH Copilot) spawns login
    # shells that don't honor ZDOTDIR, so dotfiles must live at the canonical
    # legacy location for their initialization to take effect. History is
    # still kept under $XDG_STATE_HOME (see `history.path` below).
    dotDir = config.home.homeDirectory;
    enableCompletion = true;
    defaultKeymap = "viins";

    # Ghost-text suggestions from history and syntax coloring as you type.
    # Both are cheap (~100KB) and a huge quality-of-life on an ephemeral box
    # where you re-run the same commands constantly.
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreAllDups = true;
      ignoreSpace = true;
      extended = true;
      append = true;
      path = "${config.xdg.stateHome}/zsh_history";
    };

    envExtra = ''
      export NODE_NO_WARNINGS=1
      export MANPAGER="nvim +Man!"
    '';

    initContent = lib.mkMerge [
      (lib.mkOrder 1000 ''
        if [[ -f ~/.config/secrets/shell.zsh ]]; then
          source ~/.config/secrets/shell.zsh
        fi

        typeset -U path PATH
        path=(
          "$HOME/.local/bin"
          "$HOME/.nix-profile/bin"
          "/etc/profiles/per-user/${config.home.username}/bin"
          "/nix/var/nix/profiles/default/bin"
          $path
        )
      '')

      (lib.mkAfter ''
        bindkey '^k' forward-char
        bindkey '^j' backward-char
      '')
    ];
  };
}
