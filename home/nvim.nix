{ inputs, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    # Remote plugin hosts: disabled. Modern Lua-first configs don't need them.
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;

    # LSPs the agent box actually uses day-to-day.
    # Dropped: typescript (huge, pulled by tsserver anyway), bash-language-server
    # (rarely used interactively), vscode-langservers-extracted (HTML/CSS/JSON
    # LSPs you can install via mason on demand). tree-sitter kept — required
    # by nvim-treesitter runtime parsers.
    # On PATH for nvim plugins (Telescope, fzf-lua, gitsigns, etc.) regardless
    # of the user's shell-resolved PATH.
    extraPackages = with pkgs; [
      ripgrep
      fd
      fzf
      git
      gh
      bat
      tree-sitter
      lua-language-server
      stylua
      typescript-language-server
    ];
  };

  xdg.configFile."nvim" = {
    source = "${inputs.nvim-config}/config/nvim";
    recursive = true;
  };
}
