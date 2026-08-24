# Herdr cockpit entrypoint.
#
# Open Herdr, select any workspace tab, cd to the project folder, and type
# `hc`. Codex, workers, and lazygit use that project folder; the named
# idea-center Claude pane always uses ~/Documents/github/idea.
# This function controls the existing Herdr server through its pane API. It
# never invokes bare `herdr`, which would try to launch a nested Herdr session
# from inside the current pane.

_hc_call() {
  if ! test "${HERDR_ENV:-}" = 1; then
    print -u2 -- 'hc requires a Herdr-managed pane (HERDR_ENV=1).'
    return 1
  fi

  if (( $# == 0 )); then
    print -u2 -- 'hc refused an empty Herdr command; nested Herdr launch is disabled.'
    return 2
  fi

  case "$1" in
    pane|tab|workspace|agent)
      command herdr "$@"
      ;;
    *)
      print -u2 -- "hc only permits Herdr control subcommands, got: $1"
      return 2
      ;;
  esac
}

_hc_wait_for_shell() {
  emulate -L zsh
  local pane_id="$1"
  local process_info
  local attempt

  for attempt in {1..120}; do
    if process_info="$(_hc_call pane process-info --pane "$pane_id" 2>/dev/null)" &&
       print -r -- "$process_info" | command jq -e '
         (.result.process_info.shell_pid != null) and
         ((.result.process_info.foreground_processes | length) == 1) and
         (.result.process_info.foreground_processes[0].pid == .result.process_info.shell_pid)
       ' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done

  print -u2 -- "Pane $pane_id did not become an available shell within 30 seconds."
  return 1
}

_hc_wait_for_agent_kind() {
  emulate -L zsh
  local pane_id="$1"
  local expected_kind="$2"
  local pane_info
  local attempt

  for attempt in {1..120}; do
    if pane_info="$(_hc_call pane get "$pane_id" 2>/dev/null)" &&
       print -r -- "$pane_info" | command jq -e --arg expected "$expected_kind" \
         '.result.pane.agent == $expected' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done

  print -u2 -- "Pane $pane_id did not report agent kind $expected_kind within 30 seconds."
  return 1
}

_hc_wait_for_process_name() {
  emulate -L zsh
  local pane_id="$1"
  local expected_name="$2"
  local process_info
  local attempt

  for attempt in {1..120}; do
    if process_info="$(_hc_call pane process-info --pane "$pane_id" 2>/dev/null)" &&
       print -r -- "$process_info" | command jq -e --arg expected "$expected_name" '
         any(.result.process_info.foreground_processes[]?;
           ((.name // .argv0 // "") == $expected)
         )
       ' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done

  print -u2 -- "Pane $pane_id did not report process $expected_name within 30 seconds."
  return 1
}

_hc_run_alias() {
  emulate -L zsh
  local pane_id="$1"
  local command_text="$2"
  local run_output

  if ! run_output="$(_hc_call pane run "$pane_id" "$command_text" 2>&1)"; then
    print -u2 -- "Failed to run $command_text in pane $pane_id."
    print -u2 -- "$run_output"
    return 1
  fi
}

_hc_start_agent() {
  emulate -L zsh
  local pane_id="$1"
  local agent_name="$2"
  local agent_kind="$3"
  shift 3
  local -a start_args
  local start_output

  start_args=(agent start "$agent_name" --kind "$agent_kind" --pane "$pane_id")
  if (( $# > 0 )); then
    start_args+=(-- "$@")
  fi

  if ! start_output="$(_hc_call "${start_args[@]}" 2>&1)"; then
    print -u2 -- "Failed to start $agent_name in pane $pane_id."
    print -u2 -- "$start_output"
    return 1
  fi
}

_hc_named_agents_ready() {
  emulate -L zsh
  local agent_name

  for agent_name in idea-center worker-1 worker-2 worker-3; do
    _hc_call agent get "$agent_name" >/dev/null 2>&1 || return 1
  done
}

hc() {
  emulate -L zsh
  setopt localoptions pipefail

  if (( $# > 0 )); then
    if [[ "$1" == '-h' || "$1" == '--help' ]]; then
      print -r -- 'Usage: hc'
      print -r -- '  Detect the current Herdr workspace, tab, and project folder, then start the six-pane Codex cockpit.'
      return 0
    fi
    print -u2 -- 'Usage: hc'
    return 2
  fi

  if ! test "${HERDR_ENV:-}" = 1; then
    print -u2 -- 'hc must be run inside the existing Herdr session; it will not start a nested Herdr session.'
    return 1
  fi

  local required_command
  for required_command in herdr jq sleep claude agy codex pi lazygit; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
      print -u2 -- "hc requires command: $required_command"
      return 1
    fi
  done

  local required_alias
  for required_alias in codexyolo; do
    if ! alias "$required_alias" >/dev/null 2>&1; then
      print -u2 -- "hc requires zsh alias $required_alias; reload ~/.zshrc first."
      return 1
    fi
  done

  local cockpit_cwd="${PWD:A}"
  if [[ ! -d "$cockpit_cwd" ]]; then
    print -u2 -- "Current folder is not available: $cockpit_cwd"
    return 1
  fi

  local idea_cwd="${HOME}/Documents/github/idea"
  idea_cwd="${idea_cwd:A}"
  if [[ ! -d "$idea_cwd" || ! -e "$idea_cwd/.git" ]]; then
    print -u2 -- "Idea center repo is not available: $idea_cwd"
    return 1
  fi

  local current_json
  if ! current_json="$(_hc_call pane current --current)"; then
    print -u2 -- 'hc could not inspect the current Herdr pane.'
    return 1
  fi

  local workspace_id tab_id controller_pane current_agent
  if ! workspace_id="$(print -r -- "$current_json" | command jq -er '.result.pane.workspace_id')" ||
     ! tab_id="$(print -r -- "$current_json" | command jq -er '.result.pane.tab_id')" ||
     ! controller_pane="$(print -r -- "$current_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc received an invalid current-pane response from Herdr.'
    return 1
  fi
  current_agent="$(print -r -- "$current_json" | command jq -r '.result.pane.agent // empty')"

  if [[ "${HERDR_WORKSPACE_ID:-}" != "$workspace_id" ||
        "${HERDR_TAB_ID:-}" != "$tab_id" ||
        "${HERDR_PANE_ID:-}" != "$controller_pane" ]]; then
    print -u2 -- 'Herdr caller context does not match the current-pane response; refusing to continue.'
    return 1
  fi

  local workspace_panes tab_pane_count
  if ! workspace_panes="$(_hc_call pane list --workspace "$workspace_id")" ||
     ! tab_pane_count="$(print -r -- "$workspace_panes" | command jq -er --arg tab "$tab_id" \
       '[.result.panes[] | select(.tab_id == $tab)] | length')"; then
    print -u2 -- "hc could not inspect panes in workspace $workspace_id."
    return 1
  fi

  local same_cockpit
  if [[ "$tab_pane_count" == 6 ]]; then
    same_cockpit="$(print -r -- "$workspace_panes" | command jq -er \
      --arg tab "$tab_id" --arg project_cwd "$cockpit_cwd" --arg idea_cwd "$idea_cwd" '
      [.result.panes[] | select(.tab_id == $tab)] as $panes
      | (
          ($panes | length) == 6
          and (($panes | map(.agent // "") | sort) == ["", "agy", "claude", "codex", "pi", "pi"])
          and ([$panes[] | select((.agent // "") == "" and (.terminal_title_stripped // "") == "lazygit" and ((.cwd // .foreground_cwd // "") == $project_cwd))] | length == 1)
          and ([$panes[] | select((.agent // "") == "claude" and ((.cwd // .foreground_cwd // "") == $idea_cwd))] | length == 1)
          and ([$panes[] | select((.agent // "") != "claude" and ((.cwd // .foreground_cwd // "") == $project_cwd))] | length == 5)
        )
    ' 2>/dev/null)"
    if [[ "$same_cockpit" == true ]] && _hc_named_agents_ready; then
      print -r -- "Herdr cockpit already active in workspace $workspace_id, tab $tab_id, project $cockpit_cwd, idea-center $idea_cwd."
      return 0
    fi
    print -u2 -- 'The current tab already has six panes, but they are not the expected six-pane cockpit; refusing to rearrange them.'
    return 1
  fi

  if [[ "$tab_pane_count" != 1 ]]; then
    print -u2 -- "The current tab has $tab_pane_count panes; hc only expands a single-pane tab into the six-pane cockpit and will not rearrange existing panes."
    return 1
  fi

  if [[ -n "$current_agent" && "$current_agent" != 'codex' ]]; then
    print -u2 -- "The current pane is agent $current_agent, not the Codex main agent; refusing to replace it."
    return 1
  fi

  local split_json lazygit_pane claude_pane worker_1_pane worker_2_pane worker_3_pane
  if ! split_json="$(_hc_call pane split "$controller_pane" --direction down --cwd "$idea_cwd" --no-focus)" ||
     ! claude_pane="$(print -r -- "$split_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc could not create the bottom-left Claude pane.'
    return 1
  fi
  if ! split_json="$(_hc_call pane split "$controller_pane" --direction right --cwd "$cockpit_cwd" --no-focus)" ||
     ! lazygit_pane="$(print -r -- "$split_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc could not create the top-right lazygit pane.'
    return 1
  fi
  if ! split_json="$(_hc_call pane split "$lazygit_pane" --direction down --cwd "$cockpit_cwd" --no-focus)" ||
     ! worker_1_pane="$(print -r -- "$split_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc could not create worker-1 below lazygit.'
    return 1
  fi
  if ! split_json="$(_hc_call pane split "$claude_pane" --direction right --cwd "$cockpit_cwd" --no-focus)" ||
     ! worker_2_pane="$(print -r -- "$split_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc could not create worker-2 beside Claude.'
    return 1
  fi
  if ! split_json="$(_hc_call pane split "$worker_2_pane" --direction down --cwd "$cockpit_cwd" --no-focus)" ||
     ! worker_3_pane="$(print -r -- "$split_json" | command jq -er '.result.pane.pane_id')"; then
    print -u2 -- 'hc could not create worker-3 below worker-2.'
    return 1
  fi

  _hc_wait_for_shell "$lazygit_pane" || return 1
  _hc_wait_for_shell "$worker_1_pane" || return 1
  _hc_wait_for_shell "$worker_2_pane" || return 1
  _hc_wait_for_shell "$worker_3_pane" || return 1
  _hc_wait_for_shell "$claude_pane" || return 1

  _hc_run_alias "$lazygit_pane" lazygit || return 1
  _hc_wait_for_process_name "$lazygit_pane" lazygit || return 1
  _hc_start_agent "$worker_1_pane" worker-1 agy --dangerously-skip-permissions || return 1
  _hc_wait_for_agent_kind "$worker_1_pane" agy || return 1
  _hc_start_agent "$worker_2_pane" worker-2 pi || return 1
  _hc_wait_for_agent_kind "$worker_2_pane" pi || return 1
  _hc_start_agent "$worker_3_pane" worker-3 pi || return 1
  _hc_wait_for_agent_kind "$worker_3_pane" pi || return 1
  _hc_start_agent "$claude_pane" idea-center claude --dangerously-skip-permissions --rc || return 1
  _hc_wait_for_agent_kind "$claude_pane" claude || return 1

  if [[ -z "$current_agent" ]]; then
    # The current shell is executing hc. Queue the main agent last so the
    # command starts after this function returns to that shell.
    _hc_run_alias "$controller_pane" codexyolo || return 1
  fi

  print -r -- 'Herdr cockpit started without launching a nested Herdr session.'
  print -r -- "workspace: $workspace_id"
  print -r -- "tab: $tab_id"
  print -r -- "project folder: $cockpit_cwd"
  print -r -- "idea-center folder: $idea_cwd"
  print -r -- "top-left orchestrator/codexyolo: $controller_pane"
  print -r -- "bottom-left idea-center/claude: $claude_pane"
  print -r -- "right-top lazygit: $lazygit_pane"
  print -r -- "right-worker-1/agy: $worker_1_pane"
  print -r -- "right-worker-2/pi: $worker_2_pane"
  print -r -- "right-worker-3/pi: $worker_3_pane"
}
