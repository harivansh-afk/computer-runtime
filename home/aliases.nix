{
  programs.zsh.shellAliases = {
    cc = "claude --dangerously-skip-permissions";
    co = "codex --dangerously-bypass-approvals-and-sandbox";

    gs = "git status";
    gd = "git diff";
    gc = "git commit";
    gk = "git checkout";
    gp = "git push";
    gpo = "git pull origin";
    lg = "lazygit";

    cl = "clear";
    nim = "nvim .";
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    cat = "bat";
  };
}
