[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/getcompanion-ai/computer-nix)

<img width="959" height="638" alt="image" src="https://github.com/user-attachments/assets/239a5c42-81e4-443a-97d8-ce0e8588feb6" />

Runtime flow in a few sentences

  Authoring side (your laptop): just nvim-prompts reads ../nvim-wiki/wiki/tasks/*.md and writes 20 tiny seed prompts to
  prompts/nvim/. just nvim-factory <jobs> then calls scripts/prompt-factory.sh, which plans a handle per prompt
  (nvim-<slug>) and fans out to scripts/spawn-agent.sh with bounded -j concurrency.

  Per-box flow (inside spawn-agent.sh, idempotent via ~/.cache/computer-nix/*.done markers): computer create →
  bootstrap.sh (install Nix + run home-manager switch --flake $FLAKE_REF, which pulls skills.nix and installs the tmux,
  find-skills, agent-browser skills into ~/.claude/skills/) → auth-apply.sh (push your gh token) → secrets-apply.sh
  (skipped, no secrets.json) → curl-install Devin CLI → rsync your laptop's ~/.local/share/devin/credentials.toml onto
  the box → repos-apply.sh clones harivansh-afk/nvim-wiki + neovim/neovim into ~/work/ → upload the prompt to
  ~/prompts/<handle>.md → tmux new-session -d -s devin -c ~/work/nvim-wiki "devin --prompt-file ~/prompts/<handle>.md
  --permission-mode dangerous".

  Agent side: Devin boots already inside tmux (so $TMUX is set and the tmux subagent skill works), reads wiki/runtime.md
   + its task brief, spawns tmux-window subagents to parallelize grepping neovim source, writes
  wiki/findings/<slug>/findings.md, then runs the pull-rebase-push retry loop to land on main of
  harivansh-afk/nvim-wiki.

  To trigger: just nvim-prompts once, then just nvim-factory 5 (5 parallel spawns). Attach to any agent with computer
  ssh <handle> -- tmux attach -t devin.
