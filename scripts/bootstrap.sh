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
  # no daemon is started automatically. Two flavors of installer exist on
  # these images:
  #   * classic nix-daemon at /nix/var/nix/profiles/default/bin/nix-daemon
  #   * Determinate Nix (determinate-nixd at /usr/local/bin/determinate-nixd)
  # Detect which one is available and launch it. The socket path exists on
  # both, so we probe by actually talking to the daemon.
  daemon_up() {
    [ -S /nix/var/nix/daemon-socket/socket ] || return 1
    # `nix store ping` returns 0 only if the daemon is actually listening.
    nix store ping >/dev/null 2>&1
  }

  if ! daemon_up; then
    echo "starting nix daemon"
    if command -v determinate-nixd >/dev/null 2>&1; then
      sudo -n sh -c "nohup determinate-nixd daemon >/tmp/nix-daemon.log 2>&1 &"
    elif [ -x /nix/var/nix/profiles/default/bin/nix-daemon ]; then
      sudo -n sh -c "nohup /nix/var/nix/profiles/default/bin/nix-daemon >/tmp/nix-daemon.log 2>&1 &"
    else
      echo "no nix daemon binary found" >&2; exit 1
    fi
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
      daemon_up && break
      sleep 1
    done
    if ! daemon_up; then
      echo "nix daemon failed to come up. last log:" >&2
      tail -40 /tmp/nix-daemon.log >&2 || true
      exit 1
    fi
    echo "nix daemon is up"
  fi
'

echo "==> applying home-manager flake"
# Snapshot the current generation path before the apply so we can tell if a
# new one got produced even if ssh drops its connection on the way out.
before="$(remote 'readlink -f ~/.local/state/nix/profiles/home-manager 2>/dev/null || echo none' 2>/dev/null | tr -d '\r' || echo none)"

# Each home-manager activation creates *.backup files next to any managed
# target. A second run with the same suffix fails because the old .backup
# already exists. Rotate the suffix per run so re-applies are idempotent.
backup_suffix="backup-$(date +%Y%m%d%H%M%S)"

hm_rc=0
remote "
  set -e
  export PATH=\"\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH\"
  nix --log-format bar-with-logs run nixpkgs#home-manager -- switch --flake '${flake_ref}' -b '${backup_suffix}' --refresh --no-write-lock-file
" || hm_rc=$?

# ssh sometimes exits 255 after home-manager finishes cleanly (control socket
# teardown, idle timeout, etc.). Confirm success by checking whether a new
# home-manager generation was produced.
after="$(remote 'readlink -f ~/.local/state/nix/profiles/home-manager 2>/dev/null || echo none' 2>/dev/null | tr -d '\r' || echo none)"

if [[ "$hm_rc" -eq 0 ]]; then
  :
elif [[ "$after" != "none" && "$after" != "$before" ]]; then
  echo "==> home-manager succeeded (ssh dropped on exit, but a new generation was created)"
elif [[ "$hm_rc" -eq 255 && "$after" == "$before" && "$after" != "none" ]]; then
  # Pure no-op reapply where ssh dropped. Fine.
  echo "==> home-manager was already up to date"
else
  echo "==> home-manager failed (exit $hm_rc, no new generation)" >&2
  exit "$hm_rc"
fi

echo "==> done. connect with: computer ssh $handle --tmux"
