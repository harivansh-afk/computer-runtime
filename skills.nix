# Declarative list of agent skills to install globally on the box.
#
# Each skill is passed to `npx skills add <source> --skill <name> -g -y
# --agent claude-code --agent codex` during home-manager activation
# (via ./home/skills.nix). Skills land in ~/.claude/skills/<name> and
# ~/.codex/skills/<name> only — NOT the ~40 other agents the `skills` CLI
# knows about.
#
# To change which agents get targeted, edit `targetAgents` in home/skills.nix.
#
# Only re-runs the installer when this list (or the agent list) changes
# (content-addressed by hash).
#
# Edit freely. Set `skills = [ ];` to opt out entirely.
{
  skills = [
    {
      name = "find-skills";
      source = "https://github.com/vercel-labs/skills";
    }
    {
      name = "agent-browser";
      source = "https://github.com/vercel-labs/agent-browser";
    }
    # Lets the parent Devin agent fan out into tmux-windowed subagents for
    # parallel research/grep/reading without burning the parent's context.
    # Required by the nvim-wiki prompt factory.
    {
      name = "tmux";
      source = "https://github.com/harivansh-afk/tmux-subagents";
    }
  ];
}
