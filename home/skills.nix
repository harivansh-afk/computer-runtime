{
  config,
  lib,
  pkgs,
  ...
}:
let
  userSkills = (import ../skills.nix).skills or [ ];

  # Only install skills for the two agents we actually run on these boxes.
  # Without this, `skills add` fans out to ~40 agents (cursor, windsurf,
  # gemini-cli, github-copilot, ...), creating a pile of directories under
  # ~/.<agent>/skills that are never read.
  targetAgents = [
    "claude-code"
    "codex"
  ];

  # Global install lands in per-agent dirs: claude-code → ~/.claude/skills,
  # codex → ~/.codex/skills. Keep this map in sync with `targetAgents`.
  agentGlobalDirs = {
    "claude-code" = ".claude/skills";
    "codex" = ".codex/skills";
  };

  # Content-addressed stamp: the activation script skips entirely when the
  # desired hash matches what's on disk. Include targetAgents so toggling
  # agents forces a resync, but NOT agentGlobalDirs — those are implementation
  # detail of where `skills add` writes, not user-visible intent.
  manifestHash = builtins.hashString "sha256" (
    builtins.toJSON {
      inherit userSkills targetAgents;
    }
  );

  # The manifest the activation script reads. Separate from the hash input on
  # purpose so we can evolve the manifest schema (e.g. add agentDirs) without
  # invalidating every box's stamp file.
  manifest = pkgs.writeText "skills-manifest.json" (
    builtins.toJSON {
      agents = targetAgents;
      skills = userSkills;
      agentDirs = agentGlobalDirs;
    }
  );

  # Extracted from an inline ~60-line bash blob inside home.activation so
  # shellcheck runs at build time, not the first time a box activates.
  ensure-skills = pkgs.writeShellApplication {
    name = "ensure-skills";
    runtimeInputs = with pkgs; [
      nodejs_22
      git
      jq
      coreutils
      findutils
      gnugrep
      gnused
    ];
    text = builtins.readFile ./ensure-skills.sh;
    bashOptions = [
      "errexit"
      "nounset"
      "pipefail"
    ];
  };
in
{
  home.activation.ensureGlobalSkills =
    if userSkills == [ ] then
      lib.hm.dag.entryAfter [ "writeBoundary" ] ": # no skills configured"
    else
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${ensure-skills}/bin/ensure-skills \
          ${manifest} \
          ${lib.escapeShellArg manifestHash} \
          "${config.xdg.stateHome}/skills"
      '';
}
