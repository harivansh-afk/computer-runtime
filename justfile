set dotenv-load := true

default:
  @just --list

# --- box targets -------------------------------------------------------------

# One-shot onboarding: pick box once, idempotent. Repos always prompts. Pass 'force' to redo.
go handle='' mode='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/go.sh "$h" '{{ mode }}'

# Apply the flake to a computer
switch handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/bootstrap.sh "$h"

# Push laptop-side gh auth onto the box (for private repos)
auth handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/auth-apply.sh "$h"

# Copy agent credentials (claude + codex) onto a computer
agent handle='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/pick-agent.sh "$h"

# Create a new computer using COMPUTER_SIZE + COMPUTER_DISK_GIB from .env
create handle:
  computer create --size ${COMPUTER_SIZE} --storage ${COMPUTER_DISK_GIB:-30} {{ handle }}

# --- manifests ---------------------------------------------------------------

# Declaratively apply ./secrets.json. Pass 'force' to hard-overwrite.
secrets handle='' mode='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/secrets-apply.sh "$h" secrets.json '{{ mode }}'

# Interactive picker: generates secrets.json (run once, then commit)
secrets-init:
  ./scripts/secrets-init.sh

# Declaratively apply ./repos.json. Safe by default (ff-only). Pass 'force' for hard reset.
repos handle='' mode='':
  #!/usr/bin/env bash
  set -euo pipefail
  h="$(./scripts/pick-handle.sh '{{ handle }}')"
  ./scripts/repos-apply.sh "$h" repos.json '{{ mode }}'

# Interactive picker: generates repos.json (run once, then commit)
repos-init:
  ./scripts/repos-init.sh

# --- prompt factory ----------------------------------------------------------

# Spawn one Devin agent end-to-end on a fresh box, seeded with <prompt-file>.
spawn handle prompt repos='repos.json':
  ./scripts/spawn-agent.sh {{ handle }} {{ prompt }} {{ repos }}

# Fan out one agent per prompt file in <dir>. Extra args are passed through
# (e.g. `just factory ./prompts -- --prefix vuln -j 4`).
factory dir *args:
  ./scripts/prompt-factory.sh {{ dir }} {{ args }}

# --- nvim-wiki bug-hunting factory ------------------------------------------

# Generate one prompt per wiki/tasks/*.md brief into ./prompts/nvim/
nvim-prompts wiki='':
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -n "{{ wiki }}" ]]; then
    ./scripts/nvim-prompts.sh --wiki '{{ wiki }}'
  else
    ./scripts/nvim-prompts.sh
  fi

# Spawn 20 agents in parallel, one per nvim-wiki task.
# Requires: ./prompts/nvim/ populated (run `just nvim-prompts` first).
# `dangerous` permission mode is set so agents can tmux-spawn subagents and
# git-push findings without interactive approval.
nvim-factory jobs='5':
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ ! -d ./prompts/nvim ]] || ! compgen -G "./prompts/nvim/*.md" >/dev/null; then
    echo "no prompts yet — run: just nvim-prompts" >&2
    exit 1
  fi
  export DEVIN_PERMISSION_MODE="${DEVIN_PERMISSION_MODE:-dangerous}"
  ./scripts/prompt-factory.sh ./prompts/nvim \
    --prefix nvim \
    --repos repos.nvim-wiki.json \
    -j '{{ jobs }}'

# --- dev ---------------------------------------------------------------------

# Format every *.nix file with nixfmt
fmt:
  nix --extra-experimental-features 'nix-command flakes' fmt

# Evaluate the flake (catch broken modules before switching)
check:
  nix --extra-experimental-features 'nix-command flakes' flake check --no-build

# Shellcheck every script in scripts/
lint:
  nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#shellcheck \
    -c shellcheck scripts/*.sh
