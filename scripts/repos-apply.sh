#!/usr/bin/env bash
# Declaratively clone/update the repos listed in ./repos.json onto the box.
#
# Safe by default: existing checkouts are updated with `git pull --ff-only`,
# so uncommitted or non-fast-forward work is never silently discarded. Pass
# `force` as the third arg to hard-reset to origin/<branch> (matches the
# `just go mybox force` convention).
set -euo pipefail

handle="${1:?usage: repos-apply.sh <handle> [manifest] [force]}"
manifest="${2:-repos.json}"
mode="${3:-}"

if [[ ! -f "$manifest" ]]; then
  echo "no manifest at $manifest — copy repos.example.json to repos.json" >&2
  exit 1
fi
if ! command -v jq >/dev/null; then
  echo "jq required" >&2; exit 1
fi

force=0
[[ "$mode" == "force" ]] && force=1

root="$(jq -r '.root // "~/work"' "$manifest")"
count="$(jq '.repos | length' "$manifest")"
if [[ "$count" -eq 0 ]]; then
  echo "no repos declared in $manifest"; exit 0
fi

echo "==> syncing $count repo(s) to $handle under $root"

# One line per repo: `repo\tdest\tbranch\tdepth`. The remote loop reads stdin
# rather than interpolating the plan into the ssh command — no quote gymnastics.
plan="$(
  jq -r --arg root "$root" '
    .repos[] |
    [ .repo,
      (.dest // ($root + "/" + (.repo|split("/")|.[-1]))),
      (.branch // ""),
      (.depth // "" | tostring)
    ] | @tsv
  ' "$manifest"
)"

# Concatenate the remote driver + the plan, pipe both via stdin to a plain
# `bash -s` on the box. Avoids the heredoc-vs-pipe collision (SC2259) and the
# nested-quoting dance of embedding a \t in a single-quoted remote command.
read -r -d '' remote_driver <<'REMOTE' || true
set -e
if ! command -v git >/dev/null 2>&1; then
  echo "git not installed on box; run 'just switch' first" >&2
  exit 1
fi
FORCE="${FORCE:-0}"
# Read plan lines from stdin; the driver itself is the head of this stream,
# terminated by __PLAN__ so we know where data starts.
reached_data=0
while IFS=$'\t' read -r repo dest branch depth; do
  if [ "$reached_data" = "0" ]; then
    [ "$repo" = "__PLAN__" ] && reached_data=1
    continue
  fi
  [ -z "$repo" ] && continue
  dest="${dest/#\~/$HOME}"
  mkdir -p "$(dirname "$dest")"

  if [ -d "$dest/.git" ]; then
    echo "  updating $repo → $dest"
    git -C "$dest" fetch --quiet --all --prune
    if [ -n "$branch" ]; then
      git -C "$dest" checkout --quiet "$branch" 2>/dev/null \
        || git -C "$dest" checkout --quiet -B "$branch" "origin/$branch"
      if [ "$FORCE" = "1" ]; then
        git -C "$dest" reset --quiet --hard "origin/$branch"
      else
        if ! git -C "$dest" merge --quiet --ff-only "origin/$branch"; then
          echo "    ! non-fast-forward on $dest (local commits or dirty tree)."
          echo "    ! leaving as-is. re-run with 'force' to hard-reset." >&2
        fi
      fi
    fi
  else
    echo "  cloning $repo → $dest"
    args=( --quiet )
    [ -n "$branch" ] && args+=( --branch "$branch" )
    [ -n "$depth"  ] && args+=( --depth  "$depth"  )
    git clone "${args[@]}" "https://github.com/$repo.git" "$dest"
  fi
done
REMOTE

{
  printf '%s\n' "$remote_driver"
  printf '__PLAN__\n'
  printf '%s\n' "$plan"
} | computer ssh "$handle" -- FORCE="$force" bash -s

echo "==> repos synced"
