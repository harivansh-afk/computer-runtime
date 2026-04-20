#!/usr/bin/env bash
# One-shot onboarding for a new computer.
#
# Steps are idempotent per-box: each one writes a marker file on the box at
# ~/.cache/computer-nix/<step>.done and skips on re-run. Pass 'force' as the
# second arg to wipe markers and redo every step.
#
# The repos picker always runs (new task → new repos).
set -euo pipefail

handle="${1:?usage: go.sh <handle> [force]}"
mode="${2:-}"

marker_dir='~/.cache/computer-nix'

done_on_box() { computer ssh "$handle" -- "test -f ${marker_dir}/$1.done" >/dev/null 2>&1; }
mark_done()   { computer ssh "$handle" -- "mkdir -p ${marker_dir} && touch ${marker_dir}/$1.done" >/dev/null; }
step()        { ./scripts/run-step.sh "$@"; }
skip()        { printf '  \033[90m·\033[0m [%s] %s · skipped\n' "$1" "$2"; }

echo "==> onboarding $handle"
if [[ "$mode" == "force" ]]; then
  echo "    force: wiping markers on $handle"
  computer ssh "$handle" -- "rm -rf ${marker_dir}" >/dev/null 2>&1 || true
fi

step "1/5" "switch (home-manager)" ./scripts/bootstrap.sh "$handle"

if done_on_box auth; then
  skip "2/5" "gh auth"
else
  step "2/5" "gh auth" ./scripts/auth-apply.sh "$handle"
  mark_done auth
fi

if done_on_box secrets; then
  skip "3/5" "secrets"
else
  if [[ ! -f secrets.json ]]; then
    echo "    no secrets.json yet — launching picker"
    ./scripts/secrets-init.sh
  fi
  step "3/5" "secrets" ./scripts/secrets-apply.sh "$handle"
  mark_done secrets
fi

if done_on_box agent; then
  skip "4/5" "agent creds (claude + codex)"
else
  # Interactive OAuth / device code — run directly without the spinner wrapper
  # so the TTY is available for prompts.
  echo "  [4/5] claude login..."
  computer claude-login --computer "$handle"
  echo "  [4/5] codex login..."
  computer codex-login  --computer "$handle"
  mark_done agent
fi

echo "    picking repos..."
./scripts/repos-init.sh
step "5/5" "clone repos" ./scripts/repos-apply.sh "$handle"

echo
echo "==> done. connecting to $handle..."
exec computer ssh "$handle"
