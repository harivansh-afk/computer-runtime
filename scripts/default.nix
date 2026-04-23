# Wraps each shell script in scripts/ as a writeShellApplication so that:
#   * shellcheck runs at build time (no silent breakage)
#   * set -euo pipefail is enforced
#   * runtime dependencies are pinned in PATH
#
# `computer` and `bw` are not in nixpkgs, so they stay as ambient PATH
# dependencies (checked at runtime by the scripts themselves).
{ pkgs }:
let
  inherit (pkgs) lib;

  mkScript =
    {
      name,
      file,
      runtimeInputs ? [ ],
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile file;
      bashOptions = [
        "errexit"
        "nounset"
        "pipefail"
      ];
      # SC2016: single-quoted strings passed to remote shells (intentional).
      # SC2088: tilde inside quoted strings destined for remote expansion.
      # SC1091: sourced files live on remote boxes at runtime.
      # SC2154: PATH-injected vars (FORCE, BW_SESSION) set by callers.
      excludeShellChecks = [
        "SC2016"
        "SC2088"
        "SC1091"
        "SC2154"
      ];
    };

  common = with pkgs; [
    jq
    coreutils
    gnugrep
    gnused
    findutils
  ];

  scripts = {
    auth-apply = {
      file = ./auth-apply.sh;
      runtimeInputs = common ++ [ pkgs.gh ];
    };
    bootstrap = {
      file = ./bootstrap.sh;
      runtimeInputs = common;
    };
    go = {
      file = ./go.sh;
      runtimeInputs = common;
    };
    pick-agent = {
      file = ./pick-agent.sh;
      runtimeInputs = common ++ [ pkgs.fzf ];
    };
    pick-handle = {
      file = ./pick-handle.sh;
      runtimeInputs = common ++ [ pkgs.fzf ];
    };
    repos-apply = {
      file = ./repos-apply.sh;
      runtimeInputs = common;
    };
    repos-init = {
      file = ./repos-init.sh;
      runtimeInputs = common ++ [
        pkgs.gum
        pkgs.gh
        pkgs.fzf
      ];
    };
    run-step = {
      file = ./run-step.sh;
      runtimeInputs = common;
    };
    secrets-apply = {
      file = ./secrets-apply.sh;
      runtimeInputs = common ++ [ pkgs.gh ];
    };
    secrets-init = {
      file = ./secrets-init.sh;
      runtimeInputs = common ++ [
        pkgs.gum
        pkgs.fzf
      ];
    };
  };
in
lib.mapAttrs (name: args: mkScript ({ inherit name; } // args)) scripts
