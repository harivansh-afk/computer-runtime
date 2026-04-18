# Forking for your own setup

This template ships a minimal baseline. Fork it and make it yours.

## Files you will touch

```
.env                    FLAKE_REF, COMPUTER_SIZE, CLONE_PATH
flake.nix               inputs.nvim-config url, username
home/packages.nix       the tool list
home/aliases.nix        your shell aliases
home/prompt.nix         colors, if you want a different palette
```

## Ask Claude to adapt it

Open Claude with this repo in context and paste:

```
I use a <MacBook | Linux laptop> with the following tools I rely on daily:
<list your tools>.

My dotfiles live at <url or path>.
My fork of computer-nix is at <url>.

Task:
1. Update home/packages.nix to include my tools, one per line, inline comment only when the name isn't self-evident.
2. If any tool needs home-manager configuration, create a new home/<tool>.nix matching the existing style (no header comment, one flat attrset).
3. Import any new module from home/default.nix.
4. Keep the list minimal — only tools I'd use on an ephemeral dev box.
5. Do not add a theme system. Hardcode colors if needed.
```

## Sourcing your own nvim / zsh / dotfiles

Change the flake input in `flake.nix`:

```
nvim-config = {
  url = "github:<you>/<your-dotfiles>";
  flake = false;
};
```

Then `home/nvim.nix` picks up `${inputs.nvim-config}/config/nvim` (or adjust the path).

Run `nix flake update nvim-config` to pull the latest commit. The lockfile pins it.
