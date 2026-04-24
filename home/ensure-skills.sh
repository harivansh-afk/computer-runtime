# Idempotently install agent skills on the current box.
# Invoked from home.activation.ensureGlobalSkills in home/skills.nix.
#
# Arguments:
#   $1  path to manifest JSON
#   $2  desired sha256 hash of the manifest (content-addresses the stamp file)
#   $3  state directory (contains the stamp file)
#
# Manifest shape:
#   { "agents":    ["claude-code", "codex"],
#     "agentDirs": { "claude-code": ".claude/skills",
#                    "codex":       ".codex/skills" },
#     "skills":    [{ "name": "foo", "source": "https://..." }, ...] }
manifest="${1:?manifest path required}"
desired_hash="${2:?desired hash required}"
state_dir="${3:?state dir required}"

stamp_file="$state_dir/global-skills-manifest.sha256"
mkdir -p "$state_dir"

while IFS= read -r dir; do
  mkdir -p "$HOME/$dir"
done < <(jq -r '.agentDirs | to_entries[].value' "$manifest")

needs_sync=0
if [ ! -f "$stamp_file" ] || [ "$(cat "$stamp_file")" != "$desired_hash" ]; then
  needs_sync=1
fi

while IFS=$'\t' read -r skill dir; do
  if [ ! -e "$HOME/$dir/$skill" ]; then
    needs_sync=1
  fi
done < <(jq -r '
  .skills[] as $s |
  .agentDirs | to_entries[] |
  [$s.name, .value] | @tsv
' "$manifest")

if [ "$needs_sync" -eq 0 ]; then
  exit 0
fi

agent_flags=()
while IFS= read -r agent; do
  agent_flags+=("--agent" "$agent")
done < <(jq -r '.agents[]' "$manifest")

num_skills=$(jq -r '.skills | length' "$manifest")
num_agents=$(jq -r '.agents | length' "$manifest")
printf '==> syncing %d skill(s) for %d agent(s)\n' "$num_skills" "$num_agents"

while IFS=$'\t' read -r name source; do
  printf '  installing skill: %s\n' "$name"
  # </dev/null is load-bearing: `npx skills add` reads stdin (tty detection +
  # gum fallback), and without it the CLI eats the remaining entries off the
  # while-read loop's stdin, silently installing only the first skill.
  npx -y skills add "$source" --skill "$name" "${agent_flags[@]}" -g -y </dev/null \
    || printf '  (failed to install %s, continuing)\n' "$name"
done < <(jq -r '.skills[] | [.name, .source] | @tsv' "$manifest")

printf '%s\n' "$desired_hash" > "$stamp_file"
