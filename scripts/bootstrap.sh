#!/usr/bin/env bash
set -euo pipefail

handle="$1"
flake_ref="${FLAKE_REF:-github:getcompanion-ai/computer-nix#computer}"

echo "==> target: $handle"
echo "==> flake:  $flake_ref"

remote() { computer ssh "$handle" -- "$@"; }

if ! remote 'command -v nix >/dev/null 2>&1'; then
  echo "==> installing nix (determinate installer, no confirm)"
  remote 'curl --proto "=https" --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-confirm --init none'
fi

remote '
  set -e
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
  mkdir -p ~/.config/nix
  grep -q "experimental-features" ~/.config/nix/nix.conf 2>/dev/null \
    || echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

  # The box has no systemd, so the installer was run with --init none and
  # nix-daemon is not started automatically. Start it in the background and
  # wait for its socket to appear before continuing.
  if ! pgrep -x nix-daemon >/dev/null 2>&1; then
    echo "starting nix-daemon"
    sudo -n nohup /nix/var/nix/profiles/default/bin/nix-daemon >/tmp/nix-daemon.log 2>&1 &
    disown || true
    for i in 1 2 3 4 5 6 7 8 9 10; do
      [ -S /nix/var/nix/daemon-socket/socket ] && break
      sleep 1
    done
  fi
'

echo "==> applying home-manager flake"
remote "
  set -e
  export PATH=\"\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH\"
  # --no-write-lock-file is required because the flake source lives in the
  # read-only nix store; --refresh would otherwise fail trying to rewrite it.
  nix --log-format raw run nixpkgs#home-manager -- switch --flake '${flake_ref}' -b backup --refresh --no-write-lock-file
"

echo "==> done. connect with: computer ssh $handle --tmux"
