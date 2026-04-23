#!/usr/bin/env bash
# Prompt factory: fan out one agent per prompt file.
#
# Walks a directory of markdown prompts and calls spawn-agent.sh once per
# prompt, producing one computer-nix box per prompt. Supports bounded
# concurrency (-j) so you can cold-start N agents in parallel.
#
# Usage:
#   ./scripts/prompt-factory.sh <prompts-dir> [options]
#
# Options:
#   --prefix <str>     handle prefix (default: basename of prompts-dir)
#   --repos <path>     repos manifest (default: repos.json)
#   --pattern <glob>   file glob inside prompts-dir (default: *.md)
#   -j, --jobs <N>     max parallel spawns (default: 1 = sequential)
#   --dry-run          print what would run, don't create anything
#
# Handle naming: "<prefix>-<slug>" where <slug> is the prompt filename with
# extension stripped and non-alphanum squashed to '-'. Handles are capped at
# 40 chars (agentcomputer limit).
#
# Logs: each parallel spawn's stdout/stderr is tee'd to
#   ${COMPUTER_NIX_LOG_DIR:-/tmp/computer-nix}/factory-<handle>-<ts>.log
#
# Examples:
#   ./scripts/prompt-factory.sh ./prompts
#   ./scripts/prompt-factory.sh ./prompts --prefix vuln --repos phase3.json -j 4
#   ./scripts/prompt-factory.sh ./prompts --pattern 'phase3-*.md' -j 3
set -euo pipefail

prompts_dir=""
prefix=""
repos="repos.json"
pattern="*.md"
jobs=1
dry_run=0

usage() { sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)   prefix="$2"; shift 2 ;;
    --repos)    repos="$2"; shift 2 ;;
    --pattern)  pattern="$2"; shift 2 ;;
    -j|--jobs)  jobs="$2"; shift 2 ;;
    --dry-run)  dry_run=1; shift ;;
    -h|--help)  usage 0 ;;
    -*)         echo "unknown flag: $1" >&2; usage 1 ;;
    *)
      if [[ -z "$prompts_dir" ]]; then prompts_dir="$1"; shift
      else echo "unexpected arg: $1" >&2; usage 1; fi
      ;;
  esac
done

if [[ -z "$prompts_dir" ]]; then usage 1; fi
if [[ ! -d "$prompts_dir" ]]; then echo "not a directory: $prompts_dir" >&2; exit 1; fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

if [[ -z "$prefix" ]]; then
  prefix="$(basename "$(cd "$prompts_dir" && pwd)")"
fi
# Sanitize prefix: agentcomputer handles are [a-z0-9-], lowercase.
prefix="$(printf '%s' "$prefix" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-\|-$//g')"

log_root="${COMPUTER_NIX_LOG_DIR:-${TMPDIR:-/tmp}/computer-nix}"
mkdir -p "$log_root"

# ---------------------------------------------------------------------------
# enumerate prompts
# ---------------------------------------------------------------------------
shopt -s nullglob
# shellcheck disable=SC2086  # $pattern is a glob we deliberately let the shell expand
mapfile -t prompts < <(cd "$prompts_dir" && printf '%s\n' $pattern | sort)
if [[ ${#prompts[@]} -eq 0 ]]; then
  echo "no prompts matched '$pattern' in $prompts_dir" >&2; exit 1
fi

slug_of() {
  local name="${1##*/}"
  name="${name%.*}"
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-\|-$//g')"
  printf '%s' "$name"
}

declare -a plan_handle=() plan_prompt=()
for p in "${prompts[@]}"; do
  slug="$(slug_of "$p")"
  handle="${prefix}-${slug}"
  # agentcomputer handle max is 40 chars — truncate deterministically.
  handle="${handle:0:40}"
  handle="${handle%-}"
  plan_handle+=( "$handle" )
  plan_prompt+=( "$prompts_dir/$p" )
done

# ---------------------------------------------------------------------------
# summary
# ---------------------------------------------------------------------------
echo "==> prompt factory"
echo "    prompts:  $prompts_dir ($pattern)"
echo "    prefix:   $prefix"
echo "    repos:    $repos"
echo "    jobs:     $jobs"
echo "    count:    ${#plan_handle[@]}"
echo
for i in "${!plan_handle[@]}"; do
  printf '    %2d. %-40s  <- %s\n' "$((i+1))" "${plan_handle[$i]}" "${plan_prompt[$i]}"
done
echo

if [[ "$dry_run" -eq 1 ]]; then
  echo "(dry-run; nothing spawned)"
  exit 0
fi

# ---------------------------------------------------------------------------
# fan out
# ---------------------------------------------------------------------------
spawn_one() {
  local handle="$1" prompt="$2"
  local ts log
  ts="$(date +%Y%m%d-%H%M%S)"
  log="${log_root}/factory-${handle}-${ts}.log"
  echo "[$handle] logging to $log"
  if ./scripts/spawn-agent.sh "$handle" "$prompt" "$repos" >"$log" 2>&1; then
    printf '[%s] \033[32mok\033[0m\n' "$handle"
  else
    local rc=$?
    printf '[%s] \033[31mfailed\033[0m (exit %d) — tail:\n' "$handle" "$rc"
    tail -30 "$log" | sed 's/^/  /'
    return "$rc"
  fi
}
export -f spawn_one
export repos log_root

failures=0

if [[ "$jobs" -le 1 ]]; then
  for i in "${!plan_handle[@]}"; do
    spawn_one "${plan_handle[$i]}" "${plan_prompt[$i]}" || failures=$((failures+1))
  done
else
  # Bounded concurrency with a simple job slot table. Keeps bash-only — no xargs
  # -P quirks around exit codes or argument quoting.
  declare -A pids=()
  reap() {
    local any=0
    for h in "${!pids[@]}"; do
      local pid="${pids[$h]}"
      if ! kill -0 "$pid" 2>/dev/null; then
        wait "$pid" || failures=$((failures+1))
        unset 'pids[$h]'
        any=1
      fi
    done
    return $(( any == 0 ))  # 0 if we reaped anything
  }

  for i in "${!plan_handle[@]}"; do
    while [[ "${#pids[@]}" -ge "$jobs" ]]; do
      reap || sleep 0.5
    done
    h="${plan_handle[$i]}"; p="${plan_prompt[$i]}"
    ( spawn_one "$h" "$p" ) &
    pids["$h"]=$!
  done
  for h in "${!pids[@]}"; do
    wait "${pids[$h]}" || failures=$((failures+1))
  done
fi

echo
if [[ "$failures" -eq 0 ]]; then
  echo "==> all ${#plan_handle[@]} agent(s) spawned"
else
  echo "==> $failures/${#plan_handle[@]} agent(s) failed" >&2
  exit 1
fi
