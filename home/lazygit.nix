{ lib, ... }:
{
  # Enable the lazygit binary but don't manage config.yml declaratively.
  # lazygit needs to rewrite it during config migrations (e.g. the git.paging
  # → git.pagers rename), which EPERMs when the file is a symlink into the
  # read-only Nix store. Seed a writable copy on first run instead.
  programs.lazygit.enable = true;

  home.activation.seedLazygitConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cfg="$HOME/.config/lazygit/config.yml"
        if [ ! -e "$cfg" ] || [ -L "$cfg" ]; then
          if [ -L "$cfg" ]; then rm -f "$cfg"; fi
          mkdir -p "$(dirname "$cfg")"
          cat >"$cfg" <<'EOF'
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
    EOF
          chmod 0644 "$cfg"
        fi
  '';
}
