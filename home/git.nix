{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    package = pkgs.git;

    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rebase.autoStash = true;
      fetch.prune = true;
      diff.algorithm = "histogram";
    };

    signing.format = "openpgp";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Nord";
    };
  };
}
