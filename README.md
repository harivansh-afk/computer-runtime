## Computer Nix

<img width="3598" height="630" alt="Gemini_Generated_Image_d10lsxd10lsxd10l" src="https://github.com/user-attachments/assets/332ca256-2707-46af-b593-e5e3071a2263" />

A minimal home-manager flake and a justfile for running machines on [computer CLI](https://agentcomputer.ai).

The flake composes home-manager on `x86_64-linux` only.

Global username, flake ref, clone path, and box size are encoded in .env

Secrets live in Bitwarden and are rendered at `just secrets` time using the `bw` cli on the laptop.

The box never unlocks your vault.

Repos clone into `~/Documents/github` on the box, matching the laptop layout.

Claude and Codex are preinstalled on the computer image.

`just agent` copies local credentials onto the box via `computer claude-login` and `computer codex-login`.

Deployment is `just switch <handle>` for first-time setup and reapply.

All four commands accept a handle or prompt an fzf picker over `computer ls`.

## Quickstart

```
gh repo create my-computer-nix --template getcompanion-ai/computer-nix --public --clone
cd my-computer-nix
cp .env.example .env
computer create --size ram-4g mybox
just switch mybox
just repos mybox
just secrets mybox
just agent mybox
computer ssh mybox --tmux
```

## Commands

```
just switch    apply the flake to a box
just repos     fzf-multi-select gh repos, clone to ~/Documents/github
just secrets   fzf-multi-select bw items, render onto the box
just agent     fzf-pick claude / codex, copy credentials
```

## Forking

Edit `.env` for `FLAKE_REF`, `COMPUTER_SIZE`, `CLONE_PATH`.
Edit `home/packages.nix` to add or remove tools.
Edit `home/aliases.nix` to own your shell aliases.
Point `inputs.nvim-config` at your own dotfiles repo in `flake.nix`.

See [docs/forking.md](docs/forking.md) for the Claude prompt to adapt this template to your daily-driver machine.

## Prereqs

```
computer   — https://agentcomputer.ai/install.sh
gh         — authenticated with `gh auth login`
bw         — authenticated with `bw login && bw unlock`
just       — package manager of choice
fzf        — package manager of choice
```
