# Helpers shared across home-manager modules.
{ lib, pkgs }:
{
  # Emits a home.activation fragment that cp's a read-only source file into a
  # writable location on first run (or when the dangling symlink from a previous
  # generation is still there). Used for tools that manage their own config
  # files at runtime and can't tolerate a symlink into the read-only Nix store
  # (gh, lazygit).
  #
  # Arguments:
  #   name    — used to name the intermediate /nix/store path
  #   path    — destination relative to $HOME
  #   content — file content (multi-line string)
  mkSeedActivation =
    {
      name,
      path,
      content,
    }:
    let
      src = pkgs.writeText "seed-${name}" content;
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dest="$HOME/${path}"
      if [ ! -e "$dest" ] || [ -L "$dest" ]; then
        [ -L "$dest" ] && rm -f "$dest"
        mkdir -p "$(dirname "$dest")"
        cp "${src}" "$dest"
        chmod 0644 "$dest"
      fi
    '';
}
