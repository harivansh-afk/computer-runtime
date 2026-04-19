{ inputs, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    withNodeJs = true;
    withPython3 = false;
    withRuby = false;

    extraPackages = with pkgs; [
      ripgrep
      fd
      fzf
      gh
      git
      bat
      tree-sitter
      lua-language-server
      stylua
      typescript
      typescript-language-server
      bash-language-server
      vscode-langservers-extracted
    ];
  };

  xdg.configFile."nvim" = {
    source = "${inputs.nvim-config}/config/nvim";
    recursive = true;
  };
}
