## Computer Nix

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/getcompanion-ai/computer-nix)

<img width="auto" height="auto" alt="computer-nix" src="https://github.com/user-attachments/assets/332ca256-2707-46af-b593-e5e3071a2263" />

Home-manager flake + justfile for onboarding a fresh [agentcomputer](https://agentcomputer.ai) box into a ready-to-code environment.

One command — `just go` — picks a box, applies your flake, pushes gh/agent auth and secrets, and clones whichever repos you pick for this task.

## Quickstart

```
gh repo create my-computer-nix --template getcompanion-ai/computer-nix --public --clone
cd my-computer-nix
cp .env.example .env
computer create mybox
just go mybox
computer ssh mybox --tmux
```

`just go` is idempotent per-box: `switch / auth / secrets / agent` skip if already done on that box. The repo picker always runs (new task → new repos).

Pass `force` to redo everything: `just go mybox force`.

## Commands

| command | what it does |
| --- | --- |
| `just go [handle]` | full onboarding, idempotent |
| `just switch`      | apply the home-manager flake |
| `just auth`        | push laptop `gh` token to the box |
| `just secrets`     | apply `./secrets.json` |
| `just secrets-init`| fuzzy picker → writes `./secrets.json` |
| `just repos`       | apply `./repos.json` |
| `just repos-init`  | fuzzy picker → writes `./repos.json` |
| `just agent`       | claude + codex credentials |
| `just create`      | wraps `computer create --size $COMPUTER_SIZE` |

Minimum disk size of 30GB is recommended for this flake.

Any command that targets a box takes a `<handle>` or prompts an fzf picker over `computer ls`.

## Manifests

`secrets.json` and `repos.json` are the declarative source of truth. Both are `.gitignore`-d by default; add `-f` if you want them versioned in your fork. See `secrets.example.json` / `repos.example.json` for the schema.

## Forking

See [forking.md](forking.md) for the walkthrough, repo layout, and where to change what.

## Prereqs

```
computer   — https://agentcomputer.ai/install.sh
just       — brew install just
gum        — brew install gum
jq fzf gh  — any package manager
bw         — only if you're using Bitwarden for secrets
```
