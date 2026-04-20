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

  # Include targetAgents in the manifest hash so toggling agents forces resync.
  manifestHash = builtins.hashString "sha256" (
    builtins.toJSON {
      inherit userSkills targetAgents;
    }
  );

  agentFlags = lib.concatMapStringsSep " " (a: "--agent ${lib.escapeShellArg a}") targetAgents;

  installCommands = lib.concatMapStringsSep "\n" (skill: ''
    echo "  installing skill: ${skill.name} (agents: ${lib.concatStringsSep ", " targetAgents})"
    "${pkgs.nodejs_22}/bin/npx" -y skills add ${lib.escapeShellArg skill.source} \
      --skill ${lib.escapeShellArg skill.name} ${agentFlags} -g -y \
      || echo "  (failed to install ${skill.name}, continuing)"
  '') userSkills;

  missingChecks = lib.concatMapStringsSep "\n" (
    skill:
    lib.concatMapStringsSep "\n" (agent: ''
      if [ ! -e "$HOME/${agentGlobalDirs.${agent}}/${skill.name}" ]; then
        needs_sync=1
      fi
    '') targetAgents
  ) userSkills;
in
{
  home.activation.ensureGlobalSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    if userSkills == [ ] then
      ''
        : # no skills configured
      ''
    else
      ''
        state_dir="${config.xdg.stateHome}/skills"
        stamp_file="$state_dir/global-skills-manifest.sha256"
        desired_hash=${lib.escapeShellArg manifestHash}
        needs_sync=0

        mkdir -p "$state_dir" ${
          lib.concatMapStringsSep " " (
            a: ''"$HOME/${agentGlobalDirs.${a}}"''
          ) targetAgents
        }

        if [ ! -f "$stamp_file" ] || [ "$(cat "$stamp_file")" != "$desired_hash" ]; then
          needs_sync=1
        fi

        ${missingChecks}

        if [ "$needs_sync" -eq 1 ]; then
          export PATH="${
            lib.makeBinPath [
              pkgs.nodejs_22
              pkgs.git
              pkgs.coreutils
              pkgs.findutils
              pkgs.gnugrep
              pkgs.gnused
            ]
          }:$PATH"

          echo "==> syncing ${toString (builtins.length userSkills)} skill(s) for ${toString (builtins.length targetAgents)} agent(s)"
          ${installCommands}

          printf '%s\n' "$desired_hash" > "$stamp_file"
        fi
      ''
  );
}
