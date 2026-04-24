# computer-runtime

Home-manager flake + orchestration scripts for spinning up ephemeral
[agentcomputer.ai][ac] boxes seeded with Nix, dotfiles, Devin CLI, agent
skills, repos, and a prompt.

Fork of [`getcompanion-ai/computer-nix`][upstream].

## Usage

```bash
cp .env.example .env                    # set FLAKE_REF to your fork
just go <handle>                        # one-shot onboarding (interactive)
```

Or run one Devin agent end-to-end from a prompt file:

```bash
./scripts/spawn-agent.sh <handle> <prompt.md> <repos.json>
```

## nvim-wiki factory

Fan out 20 Devin agents — one per task brief in [`nvim-wiki`][wiki] — to
hunt vulns in [`neovim/neovim`][nvim] in parallel. Each agent uses the
[`tmux-subagents`][tmux] skill to delegate research without burning parent
context, then commits `wiki/findings/<slug>/findings.md` back to the wiki.

```bash
just nvim-prompts                       # generate prompts/nvim/*.md
just nvim-factory 5                     # spawn 20 boxes, 5 at a time
```

## Related repos

- [`nvim-wiki`][wiki] — task briefs + runtime rules the agents read
- [`tmux-subagents`][tmux] — parallel-subagent skill
- [`harivansh-afk/nix`][dotfiles] — nvim config pinned by `flake.nix`
- [`computer-nix`][upstream] — upstream template

## Structure

```
flake.nix               inputs + homeConfigurations.computer
home/                   home-manager modules
scripts/                bash recipes wrapped by the justfile
skills.nix              declarative agent-skills manifest
repos.nvim-wiki.json    repos manifest for the nvim factory
prompts/nvim/           generated seed prompts (one per task)
```

See [`forking.md`](forking.md) for the zero-to-box walkthrough.

[ac]: https://agentcomputer.ai
[upstream]: https://github.com/getcompanion-ai/computer-nix
[wiki]: https://github.com/harivansh-afk/nvim-wiki
[nvim]: https://github.com/neovim/neovim
[tmux]: https://github.com/harivansh-afk/tmux-subagents
[dotfiles]: https://github.com/harivansh-afk/nix
