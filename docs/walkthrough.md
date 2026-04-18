# Walkthrough

From zero to a working box in about five minutes.

## 1. Install prereqs

```
curl -fsSL https://agentcomputer.ai/install.sh | bash
brew install just fzf gh bitwarden-cli      # or your package manager
gh auth login
bw login && bw unlock
computer login
```

## 2. Fork and clone the template

```
gh repo create my-computer-nix --template getcompanion-ai/computer-nix --public --clone
cd my-computer-nix
cp .env.example .env
```

Edit `.env`:

```
FLAKE_REF=github:<you>/my-computer-nix#computer
COMPUTER_SIZE=ram-4g
CLONE_PATH=~/Documents/github
```

Commit the fork so the flake ref resolves:

```
git add . && git commit -m "init" && git push
```

## 3. Create a box

```
just create mybox
```

`just create` is a thin wrapper for `computer create --size $COMPUTER_SIZE mybox`.

## 4. Apply the flake

```
just switch mybox
```

Installs nix via the Determinate installer if missing, enables flakes, runs `home-manager switch --flake $FLAKE_REF -b backup`.

Re-run any time after editing the flake.

## 5. Clone your repos

```
just repos mybox
```

fzf multi-select over `gh repo list --limit 1000`. Clones into `~/Documents/github` on the box.

## 6. Render secrets

```
just secrets mybox
```

fzf multi-select over `bw list items`. Password and custom fields are rendered into `~/.config/secrets/shell.zsh` on the box (mode 600). Zsh sources this file on every shell start.

## 7. Copy agent credentials

```
just agent mybox
```

Pick claude, codex, or both.

## 8. Connect

```
computer ssh mybox --tmux
```

Your full environment is there. Exit and reattach later — tmux persists.

## Iterating

Edit any `home/*.nix`, push, `just switch mybox` again. The box pulls the new flake and reapplies. No local file sync required.

For iteration without pushing to git:

```
computer sync ./ --computer mybox
computer ssh mybox -- 'nix run nixpkgs#home-manager -- switch --flake path:/home/node/computer-nix#computer -b backup'
```
