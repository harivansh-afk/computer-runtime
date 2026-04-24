#!/usr/bin/env bash
# Generate one short Devin prompt per nvim-wiki task brief.
#
# The philosophy here is that the wiki itself carries ~95% of the context
# (runtime.md + the task brief + codebase/* maps), so the seed prompt we ship
# to the box is deliberately tiny. The agent reads the wiki on arrival.
#
# Usage:
#   ./scripts/nvim-prompts.sh [--wiki <path>] [--out <dir>] [--pattern <glob>]
#
# Defaults:
#   --wiki     ../nvim-wiki       (sibling checkout)
#   --out      ./prompts/nvim     (consumed by `just factory`)
#   --pattern  '[0-9]*.md'        (the 20 numbered task briefs, skips index.md)
#
# Output: one file per task at <out>/<task-slug>.md. Re-running overwrites.
set -euo pipefail

wiki=""
out="./prompts/nvim"
pattern='[0-9]*.md'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wiki)    wiki="$2"; shift 2 ;;
    --out)     out="$2"; shift 2 ;;
    --pattern) pattern="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

# Resolve wiki path. Prefer an explicit --wiki, else try common neighbours.
if [[ -z "$wiki" ]]; then
  for candidate in ../nvim-wiki ./nvim-wiki ~/Documents/GitHub/nvim-wiki; do
    if [[ -d "${candidate/#\~/$HOME}/wiki/tasks" ]]; then
      wiki="${candidate/#\~/$HOME}"
      break
    fi
  done
fi
if [[ -z "$wiki" || ! -d "$wiki/wiki/tasks" ]]; then
  echo "could not locate nvim-wiki checkout (pass --wiki <path>)" >&2
  exit 1
fi

mkdir -p "$out"

shopt -s nullglob
# shellcheck disable=SC2206  # $pattern is intentionally glob-expanded here
files=( "$wiki"/wiki/tasks/$pattern )
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no task files matched '$pattern' under $wiki/wiki/tasks" >&2
  exit 1
fi

echo "==> generating ${#files[@]} prompt(s) from $wiki/wiki/tasks -> $out"

for f in "${files[@]}"; do
  base="${f##*/}"              # 01-tar-extract.md
  slug="${base%.md}"           # 01-tar-extract
  # First-line H1 of the task brief → human title.
  title="$(head -n1 "$f" | sed 's/^#\+ *//')"
  dest="$out/$slug.md"

  cat >"$dest" <<EOF
# nvim-wiki task: $slug

hey — your task is **wiki/tasks/$base** in the nvim-wiki repo.

## what you have on this box

- **/home/node/workspace/nvim-wiki** — the wiki (has all the context you need)
  - \`wiki/runtime.md\` — read this first. mandatory rules for how to work.
  - \`wiki/tasks/$base\` — your specific task brief: "$title"
  - \`wiki/codebase/*.md\` — surface maps the task brief links into
  - \`wiki/index.md\` — map of every other surface if you need neighbours
- **/home/node/workspace/neovim** — the neovim source the task brief points into
  (paths in the brief like \`src/nvim/...\` resolve under here)

## what to do

1. read \`/home/node/workspace/nvim-wiki/wiki/runtime.md\` and \`/home/node/workspace/nvim-wiki/wiki/tasks/$base\` before anything else.
2. find a verifiable, reproducible exploit in the section of neovim code this task covers. chain input → normalization → policy gate → sink and name the broken invariant.
3. use the **tmux subagents skill** (\`~/.claude/skills/tmux/SKILL.md\`) aggressively. any time you are about to grep / read a lot of neovim source, delegate to a subagent so you don't burn parent context. each subagent writes to a known file; you read the file, not the pane.

## when you are done

do all of this before you exit, from inside \`/home/node/workspace/nvim-wiki\`:

1. write your findings to \`wiki/findings/$slug/findings.md\` — include:
   - the exact broken invariant
   - the input → sink chain
   - a minimal reproducer (file contents, commands, expected vs actual)
   - affected files with line refs
   - impact / severity argument
2. stage, commit, push to \`main\`. use this exact recipe so 20 agents pushing at once don't deadlock each other:

   \`\`\`bash
   cd /home/node/workspace/nvim-wiki
   git add wiki/findings/$slug/
   git commit -m "findings($slug): <one-line summary>"
   # retry loop — another agent may have pushed between your fetch and push
   for i in 1 2 3 4 5 6 7 8; do
     git pull --rebase origin main && git push origin main && break
     sleep \$((RANDOM % 5 + 1))
   done
   \`\`\`

3. only exit after \`git push\` succeeds and \`git log origin/main -1\` shows your commit.

be concise. verify. don't waste context.
EOF

  printf '  %-40s  (%s)\n' "$slug.md" "$title"
done

echo
echo "==> wrote ${#files[@]} prompt(s) to $out"
echo "    next: just factory $out -- --prefix nvim --repos repos.nvim-wiki.json -j 5"
