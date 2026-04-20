{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.pure-prompt ];

  programs.zsh.initContent = lib.mkOrder 800 ''
    fpath+=("${pkgs.pure-prompt}/share/zsh/site-functions")
    autoload -Uz promptinit && promptinit

    export PURE_PROMPT_SYMBOL=$'\xe2\x9d\xaf'
    export PURE_PROMPT_VICMD_SYMBOL=$'\xe2\x9d\xae'
    export PURE_GIT_DIRTY=""
    export PURE_GIT_UP_ARROW="^"
    export PURE_GIT_DOWN_ARROW="v"
    export PURE_GIT_STASH_SYMBOL="="
    export PURE_CMD_MAX_EXEC_TIME=5
    export PURE_GIT_PULL=0
    export PURE_GIT_UNTRACKED_DIRTY=1
    zstyle ':prompt:pure:git:stash' show yes

    zstyle ':prompt:pure:path'            color '#7aa2f7'
    zstyle ':prompt:pure:git:branch'      color '#9ece6a'
    zstyle ':prompt:pure:git:dirty'       color '#e0af68'
    zstyle ':prompt:pure:git:arrow'       color '#bb9af7'
    zstyle ':prompt:pure:prompt:success'  color '#9ece6a'
    zstyle ':prompt:pure:prompt:error'    color '#f7768e'
    zstyle ':prompt:pure:execution_time'  color '#565f89'
    zstyle ':prompt:pure:host'            color '#ebdbb2'
    zstyle ':prompt:pure:user'            color '#ebdbb2'
    zstyle ':prompt:pure:user:root'       color '#f7768e'

    typeset -g prompt_newline=' '
    prompt pure

    ${builtins.readFile ./prompt-pure-ssh-fix.zsh}
  '';
}
