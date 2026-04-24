#!/usr/bin/env bash
# Spawn one Devin agent on a fresh computer, end to end.
#
# Flow (idempotent per-box, markers under ~/.cache/computer-nix/*.done):
#   1. computer create <handle>           (skip if already exists)
#   2. bootstrap.sh                       (install nix + home-manager switch)
#   3. auth-apply.sh                      (push laptop gh token)
#   4. secrets-apply.sh                   (env vars + files from secrets.json)
#   5. install devin CLI on the box       (curl https://cli.devin.ai/install.sh)
#   6. push Devin creds declaratively     (credentials.toml + config.json)
#   7. repos-apply.sh                     (clone repos from repos-manifest)
#   8. upload prompt file                 (~/prompts/<handle>.md)
#   9. launch tmux session 'devin'        (devin -p / interactive, detached)
#
# Usage:
#   ./scripts/spawn-agent.sh <handle> <prompt-file> [repos-manifest]
#
# Env overrides (read from .env via justfile, or export directly):
#   COMPUTER_SIZE       default 'ram-4g'
#   COMPUTER_DISK_GIB   default '30'
#   FLAKE_REF           default in bootstrap.sh
#   DEVIN_MODEL         optional, e.g. 'opus'
#   DEVIN_PERMISSION_MODE  'auto' (default) or 'dangerous'
#   DEVIN_EXTRA_ARGS    appended verbatim to the devin invocation
#   AGENT_TMUX_SESSION  tmux session name on the box (default 'devin')
#
# Exit non-zero if any step fails. Safe to re-run: each sub-step self-skips
# when its marker file is present on the box.
set -euo pipefail

handle="${1:?usage: spawn-agent.sh <handle> <prompt-file> [repos-manifest]}"
prompt_file="${2:?usage: spawn-agent.sh <handle> <prompt-file> [repos-manifest]}"
repos_manifest="${3:-repos.json}"

size="${COMPUTER_SIZE:-ram-4g}"
disk="${COMPUTER_DISK_GIB:-30}"
tmux_session="${AGENT_TMUX_SESSION:-devin}"
permission_mode="${DEVIN_PERMISSION_MODE:-auto}"
model="${DEVIN_MODEL:-}"
extra_args="${DEVIN_EXTRA_ARGS:-}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

if [[ ! -f "$prompt_file" ]]; then
  echo "prompt file not found: $prompt_file" >&2; exit 1
fi

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
# shellcheck disable=SC2088  # '~' intentionally left unexpanded; expands on the remote shell
marker_dir='~/.cache/computer-nix'
remote()       { computer ssh "$handle" -- "$@"; }
done_on_box()  { remote "test -f ${marker_dir}/$1.done" >/dev/null 2>&1; }
mark_done()    { remote "mkdir -p ${marker_dir} && touch ${marker_dir}/$1.done" >/dev/null; }
log()          { printf '  \033[36m·\033[0m %s\n' "$*"; }
step()         { printf '\n==> \033[1m%s\033[0m %s\n' "$1" "$handle"; }

# ---------------------------------------------------------------------------
# 1. ensure the computer exists
# ---------------------------------------------------------------------------
step "1/9 create"
# `computer ls --json` can emit a spinner line before the JSON on interactive
# TTYs (same issue worked around in pick-handle.sh). Strip anything before the
# first `{` before feeding to jq so the existence check is reliable.
raw_ls="$(computer ls --json 2>/dev/null || true)"
json_ls="${raw_ls#"${raw_ls%%\{*}"}"
if [[ -n "$json_ls" ]] && printf '%s' "$json_ls" | jq -e --arg h "$handle" \
     '.computers[]? | select(.handle == $h)' >/dev/null 2>&1; then
  log "computer '$handle' already exists"
else
  # `computer create` rejects --size + --storage together (presets own both
  # memory and storage). If $size is a preset string (ram-2g/ram-4g/ram-8g),
  # pass only --size; otherwise interpret it as GiB and pass --memory +
  # --storage together.
  if [[ "$size" =~ ^ram-[0-9]+g$ ]]; then
    log "creating computer '$handle' (size=$size)"
    computer create --size "$size" "$handle"
  else
    log "creating computer '$handle' (memory=${size}GiB disk=${disk}GiB)"
    computer create --memory "$size" --storage "$disk" "$handle"
  fi
fi

# agentcomputer stores per-box SSH state at ~/.agentcomputer/ssh/<uuid>/.
# When a handle is deleted and re-created, the new VM's host key can land
# against a recycled UUID that still has a stale known_hosts entry, which
# breaks `computer ssh` with "REMOTE HOST IDENTIFICATION HAS CHANGED". Wipe
# the dir for this box's UUID so the first connect re-TOFUs cleanly.
fresh_ls="$(computer ls --json 2>/dev/null || true)"
fresh_json="${fresh_ls#"${fresh_ls%%\{*}"}"
box_uuid="$(printf '%s' "$fresh_json" | jq -r --arg h "$handle" \
  '.computers[]? | select(.handle == $h) | .id' 2>/dev/null || true)"
if [[ -n "$box_uuid" && -d "$HOME/.agentcomputer/ssh/$box_uuid" ]]; then
  rm -rf "$HOME/.agentcomputer/ssh/$box_uuid"
  log "cleared stale known_hosts for $box_uuid"
fi

# ---------------------------------------------------------------------------
# 2. nix + home-manager
# ---------------------------------------------------------------------------
step "2/9 bootstrap"
./scripts/bootstrap.sh "$handle"

# ---------------------------------------------------------------------------
# 3. gh auth (skip if marker present)
# ---------------------------------------------------------------------------
step "3/9 gh auth"
if done_on_box auth; then
  log "skipped (marker present)"
else
  ./scripts/auth-apply.sh "$handle"
  mark_done auth
fi

# ---------------------------------------------------------------------------
# 4. secrets manifest
# ---------------------------------------------------------------------------
step "4/9 secrets"
if done_on_box secrets; then
  log "skipped (marker present)"
elif [[ -f secrets.json ]]; then
  ./scripts/secrets-apply.sh "$handle" secrets.json
  mark_done secrets
else
  log "no secrets.json — skipping (run 'just secrets-init' to create one)"
fi

# ---------------------------------------------------------------------------
# 5. install devin CLI on the box
# ---------------------------------------------------------------------------
step "5/9 install devin"
if done_on_box devin-install; then
  log "skipped (marker present)"
else
  # The upstream installer drops the binary into ~/.local/bin/devin. That path
  # isn't in the default non-interactive SSH PATH, so we probe the symlink
  # directly rather than relying on `command -v`. The installer self-handles
  # re-runs, but skipping the curl is faster on repeat.
  # shellcheck disable=SC2016  # expanded on the remote box
  #
  # The upstream installer prints a TUI-style "Welcome to Devin for Terminal!"
  # banner after the binary is extracted and exits 130 (SIGINT) when there is
  # no TTY — which there isn't under `computer ssh ... --`. The binary itself
  # is already installed by that point, so:
  #   * redirect stdin from /dev/null
  #   * pipe the installer through `cat` to detach from any TTY expectation
  #   * verify the binary is on disk and ignore the installer's exit code
  remote '
    set -e
    export PATH="$HOME/.local/bin:$PATH"
    if [ -x "$HOME/.local/bin/devin" ]; then
      exit 0
    fi
    curl -fsSL https://cli.devin.ai/install.sh </dev/null | bash </dev/null | cat || true
    test -x "$HOME/.local/bin/devin"
  '
  mark_done devin-install
fi

# ---------------------------------------------------------------------------
# 6. push Devin credentials declaratively
#
# Devin CLI reads:
#   - ~/.local/share/devin/credentials.toml  (windsurf_api_key, api_server_url)
#   - ~/.config/devin/config.json            (agent/model/shell prefs)
#
# Both are flat files owned by the user, mode 0600. We copy them onto the box
# via `computer sync` (which drops into /home/node/) then mv into place.
# ---------------------------------------------------------------------------
step "6/9 devin creds"
if done_on_box devin-auth; then
  log "skipped (marker present)"
else
  cred_src="$HOME/.local/share/devin/credentials.toml"
  conf_src="$HOME/.config/devin/config.json"

  if [[ ! -f "$cred_src" ]]; then
    echo "no Devin credentials on this laptop ($cred_src)" >&2
    echo "run: devin auth login   (then re-run spawn-agent.sh)" >&2
    exit 1
  fi

  # Fail fast if the laptop session is stale — otherwise we'd ship a dead key.
  if ! devin auth status >/dev/null 2>&1; then
    echo "devin auth status failed on laptop; log in first: devin auth login" >&2
    exit 1
  fi

  remote '
    set -e
    mkdir -p ~/.local/share/devin ~/.config/devin
    chmod 700 ~/.local/share/devin ~/.config/devin
  ' >/dev/null

  computer sync "$cred_src" --computer "$handle" >/dev/null
  remote '
    set -e
    mv ~/credentials.toml ~/.local/share/devin/credentials.toml
    chmod 600 ~/.local/share/devin/credentials.toml
  ' >/dev/null
  log "pushed credentials.toml"

  if [[ -f "$conf_src" ]]; then
    computer sync "$conf_src" --computer "$handle" >/dev/null
    remote '
      set -e
      mv ~/config.json ~/.config/devin/config.json
      chmod 600 ~/.config/devin/config.json
    ' >/dev/null
    log "pushed config.json"
  fi

  # Sanity check: devin should report itself as logged in on the box.
  # shellcheck disable=SC2016  # $HOME/$PATH expand on the remote box, not locally
  if remote 'export PATH="$HOME/.local/bin:$PATH"; devin auth status' >/dev/null 2>&1; then
    log "devin auth status OK on $handle"
    mark_done devin-auth
  else
    echo "devin auth status failed on $handle after pushing creds" >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 7. clone repos
# ---------------------------------------------------------------------------
step "7/9 repos"
if [[ -f "$repos_manifest" ]]; then
  ./scripts/repos-apply.sh "$handle" "$repos_manifest"
else
  log "no manifest at $repos_manifest — skipping repo clone"
fi

# ---------------------------------------------------------------------------
# 8. upload prompt file
# ---------------------------------------------------------------------------
step "8/9 prompt"
prompt_name="$(basename "$prompt_file")"
remote 'mkdir -p ~/prompts' >/dev/null
computer sync "$prompt_file" --computer "$handle" >/dev/null
# Rename on box to <handle>.md so each agent has a stable, unique path.
remote "mv ~/$(printf '%q' "$prompt_name") ~/prompts/${handle}.md" >/dev/null
log "uploaded to ~/prompts/${handle}.md"

# ---------------------------------------------------------------------------
# 9. launch devin in a detached tmux session
#
# We build the command string carefully so that quoting survives the ssh hop.
# `devin --prompt-file <path>` picks up the prompt from disk (no embedding in
# argv), which keeps us clear of any quoting hell with multi-line prompts.
# ---------------------------------------------------------------------------
step "9/9 launch"

# Compose devin CLI args.
# --respect-workspace-trust false skips the interactive "do you trust this
# directory?" gate. Without it, Devin blocks on a y/n prompt inside tmux and
# the agent never sees the real task.
devin_cmd="devin --prompt-file ~/prompts/${handle}.md --permission-mode ${permission_mode} --respect-workspace-trust false"
[[ -n "$model"      ]] && devin_cmd+=" --model ${model}"
[[ -n "$extra_args" ]] && devin_cmd+=" ${extra_args}"

# Where does the agent start its shell? First repo in manifest, else $HOME.
# shellcheck disable=SC2016  # expanded on the remote box by the login shell
work_dir='$HOME'
if [[ -f "$repos_manifest" ]] && command -v jq >/dev/null; then
  first_dest="$(jq -r '
    .repos[0] as $r
    | if $r == null then empty
      else ($r.dest // ((.root // "~/work") + "/" + ($r.repo|split("/")|.[-1])))
      end
  ' "$repos_manifest")"
  if [[ -n "$first_dest" ]]; then
    work_dir="${first_dest/#\~/\$HOME}"
  fi
fi

# Kill any stale session with the same name, then re-create.
remote "
  set -e
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  tmux kill-session -t '${tmux_session}' 2>/dev/null || true
  tmux new-session -d -s '${tmux_session}' -c '${work_dir}' \
    \"${devin_cmd}; exec zsh\"
"
log "tmux session '${tmux_session}' started in ${work_dir}"
log "attach with: computer ssh $handle -- tmux attach -t ${tmux_session}"

echo
echo "==> $handle ready"
