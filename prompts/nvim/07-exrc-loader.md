# nvim-wiki task: 07-exrc-loader

hey — your task is **wiki/tasks/07-exrc-loader.md** in the nvim-wiki repo.

## what you have on this box

- **~/work/nvim-wiki** — the wiki (has all the context you need)
  - `wiki/runtime.md` — read this first. mandatory rules for how to work.
  - `wiki/tasks/07-exrc-loader.md` — your specific task brief: "# Project-local exrc loader"
  - `wiki/codebase/*.md` — surface maps the task brief links into
  - `wiki/index.md` — map of every other surface if you need neighbours
- **~/work/neovim** — the neovim source the task brief points into
  (paths in the brief like `src/nvim/...` resolve under here)

## what to do

1. read `~/work/nvim-wiki/wiki/runtime.md` and `~/work/nvim-wiki/wiki/tasks/07-exrc-loader.md` before anything else.
2. find a verifiable, reproducible exploit in the section of neovim code this task covers. chain input → normalization → policy gate → sink and name the broken invariant.
3. use the **tmux subagents skill** (`~/.claude/skills/tmux/SKILL.md`) aggressively. any time you are about to grep / read a lot of neovim source, delegate to a subagent so you don't burn parent context. each subagent writes to a known file; you read the file, not the pane.

## when you are done

do all of this before you exit, from inside `~/work/nvim-wiki`:

1. write your findings to `wiki/findings/07-exrc-loader/findings.md` — include:
   - the exact broken invariant
   - the input → sink chain
   - a minimal reproducer (file contents, commands, expected vs actual)
   - affected files with line refs
   - impact / severity argument
2. stage, commit, push to `main`. use this exact recipe so 20 agents pushing at once don't deadlock each other:

   ```bash
   cd ~/work/nvim-wiki
   git add wiki/findings/07-exrc-loader/
   git commit -m "findings(07-exrc-loader): <one-line summary>"
   # retry loop — another agent may have pushed between your fetch and push
   for i in 1 2 3 4 5 6 7 8; do
     git pull --rebase origin main && git push origin main && break
     sleep $((RANDOM % 5 + 1))
   done
   ```

3. only exit after `git push` succeeds and `git log origin/main -1` shows your commit.

be concise. verify. don't waste context.
