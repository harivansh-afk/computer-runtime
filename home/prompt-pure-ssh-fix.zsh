# Pure prompt: eager color resolution for SSH/container sessions.
#
# Pure's upstream `prompt_pure_state_setup` captures the user/host segment with
# a deferred `$prompt_pure_colors[host]` reference. When the prompt is first
# rendered (especially over SSH, where $ssh_connection triggers the user@host
# branch), that deferred reference can collapse and the segment renders in the
# terminal's default foreground instead of our theme hex.
#
# We override `prompt_pure_state_setup` to resolve the color reference eagerly,
# and re-run it from `prompt_pure_preprompt_render` so theme changes propagate
# to the user/host segment on every prompt.

prompt_pure_state_setup() {
  setopt localoptions noshwordsplit

  local ssh_connection=${SSH_CONNECTION:-$PROMPT_PURE_SSH_CONNECTION}
  local username hostname
  local pure_version=${prompt_pure_state[version]:-1.27.0}

  if [[ -z $ssh_connection ]] && (( $+commands[who] )); then
    local who_out
    who_out=$(who -m 2>/dev/null)
    if (( $? )); then
      local -a who_in
      who_in=(${(f)"$(who 2>/dev/null)"})
      who_out="${(M)who_in:#*[[:space:]]${TTY#/dev/}[[:space:]]*}"
    fi

    local reIPv6='(([0-9a-fA-F]+:)|:){2,}[0-9a-fA-F]+'
    local reIPv4='([0-9]{1,3}\.){3}[0-9]+'
    local reHostname='([.][^. ]+){2}'
    local -H MATCH MBEGIN MEND

    if [[ $who_out =~ "\(?($reIPv4|$reIPv6|$reHostname)\)?$" ]]; then
      ssh_connection=$MATCH
      export PROMPT_PURE_SSH_CONNECTION=$ssh_connection
    fi
    unset MATCH MBEGIN MEND
  fi

  hostname="%F{$prompt_pure_colors[host]}@%m%f"
  [[ -n $ssh_connection ]] && username="%F{$prompt_pure_colors[user]}%n%f""$hostname"
  [[ -z "${CODESPACES}" ]] && prompt_pure_is_inside_container && username="%F{$prompt_pure_colors[user]}%n%f""$hostname"
  [[ $UID -eq 0 ]] && username="%F{$prompt_pure_colors[user:root]}%n%f""$hostname"

  typeset -gA prompt_pure_state
  prompt_pure_state[version]="$pure_version"
  prompt_pure_state+=(username "$username" prompt "${PURE_PROMPT_SYMBOL:-❯}")
}

# Populate prompt_pure_colors from zstyles before the override reads it,
# otherwise the first render captures the pristine defaults (e.g. `host=242`)
# and emits a malformed %F{...} sequence.
prompt_pure_set_colors
prompt_pure_state_setup

prompt_pure_preprompt_render() {
  setopt localoptions noshwordsplit
  unset prompt_pure_async_render_requested

  prompt_pure_set_colors
  prompt_pure_state_setup

  typeset -g prompt_pure_git_branch_color=$prompt_pure_colors[git:branch]
  [[ -n ${prompt_pure_git_last_dirty_check_timestamp+x} ]] && prompt_pure_git_branch_color=$prompt_pure_colors[git:branch:cached]

  psvar[12]=; ((${(M)#jobstates:#suspended:*} != 0)) && psvar[12]=${PURE_SUSPENDED_JOBS_SYMBOL:-✦}
  psvar[13]=; [[ -n $prompt_pure_state[username] ]] && psvar[13]=1
  psvar[14]=${prompt_pure_vcs_info[branch]}
  psvar[15]=
  psvar[16]=${prompt_pure_vcs_info[action]}
  psvar[17]=${prompt_pure_git_arrows}
  psvar[18]=; [[ -n $prompt_pure_git_stash ]] && psvar[18]=1
  psvar[19]=${prompt_pure_cmd_exec_time}

  local expanded_prompt
  expanded_prompt="${(S%%)PROMPT}"
  if [[ $1 != precmd && $prompt_pure_last_prompt != $expanded_prompt ]]; then
    prompt_pure_reset_prompt
  fi
  typeset -g prompt_pure_last_prompt=$expanded_prompt
}
