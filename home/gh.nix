{ lib, ... }:
{
  # Enable the gh binary but don't manage config.yml declaratively — gh needs
  # to write to it during `gh auth login` and `gh auth setup-git`. A Home
  # Manager-managed symlink into the read-only Nix store would break those
  # flows. Instead we seed a default config on first run only.
  programs.gh.enable = true;

  home.activation.seedGhConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ghcfg="$HOME/.config/gh/config.yml"
        if [ ! -e "$ghcfg" ] || [ -L "$ghcfg" ]; then
          # If it's a dangling/old symlink from a previous generation, remove it.
          if [ -L "$ghcfg" ]; then rm -f "$ghcfg"; fi
          mkdir -p "$(dirname "$ghcfg")"
          cat >"$ghcfg" <<'EOF'
    git_protocol: https
    prompt: enabled
    EOF
          chmod 0644 "$ghcfg"
        fi
  '';
}
