# Herdr cockpit entrypoint.
#
# Open Herdr, select any workspace tab, cd to the project folder, and type
# `hc`. Codex, workers, and lazygit use that project folder; the workspace-
# namespaced idea-center Claude pane always uses ~/Work/github/idea.
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

_hc_workspace_namespace() {
  emulate -L zsh
  local workspace_id="$1"
  local workspace_namespace="${workspace_id:l}"

  if [[ -z "$workspace_namespace" ]]; then
    print -u2 -- 'hc cannot create an agent namespace without a workspace ID.'
    return 1
  fi

  print -r -- "$workspace_namespace"
}

_hc_agent_name() {
  emulate -L zsh
  local workspace_id="$1"
  local role="$2"
  local workspace_namespace
  local agent_name

  if [[ -z "$workspace_id" || -z "$role" ]]; then
    print -u2 -- 'hc cannot create a namespaced agent name without a workspace and role.'
    return 1
  fi

  if ! workspace_namespace="$(_hc_workspace_namespace "$workspace_id")"; then
    return 1
  fi
  agent_name="${workspace_namespace}-${role}"

  # Herdr agent names are globally unique live handles and must match
  # [a-z][a-z0-9_-]{0,31}. Mixed-case workspace IDs are lowercased into the
  # namespace; fail closed if a future Herdr version returns an ID that cannot
  # fit instead of truncating it into a possible collision.
  if [[ ! "$agent_name" =~ '^[a-z][a-z0-9_-]*$' || ${#agent_name} -gt 32 ]]; then
    print -u2 -- "Workspace $workspace_id (namespace $workspace_namespace) cannot namespace role $role as a valid Herdr agent name: $agent_name"
    return 1
  fi

  print -r -- "$agent_name"
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

_hc_wait_for_all() {
  emulate -L zsh
  local -a pids=("$@")
  local failed=0
  local pid

  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done

  return "$failed"
}

_hc_wait_for_shells() {
  emulate -L zsh
  local -a pids=()
  local pane_id

  for pane_id in "$@"; do
    _hc_wait_for_shell "$pane_id" &
    pids+=("$!")
  done

  _hc_wait_for_all "${pids[@]}"
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

_hc_start_lazygit_and_wait() {
  emulate -L zsh
  local pane_id="$1"

  _hc_run_alias "$pane_id" lazygit || return 1
  _hc_wait_for_process_name "$pane_id" lazygit
}

_hc_start_agent_and_wait() {
  emulate -L zsh
  local pane_id="$1"
  local agent_name="$2"
  local agent_kind="$3"
  shift 3

  _hc_start_agent "$pane_id" "$agent_name" "$agent_kind" "$@" || return 1
  _hc_wait_for_agent_kind "$pane_id" "$agent_kind"
}

_hc_start_all_components() {
  emulate -L zsh
  local workspace_id="$1"
  shift
  local lazygit_pane="$1"
  local worker_1_pane="$2"
  local worker_2_pane="$3"
  local worker_3_pane="$4"
  local claude_pane="$5"
  local -a pids=()
  local idea_agent_name worker_1_agent_name worker_2_agent_name worker_3_agent_name

  if ! idea_agent_name="$(_hc_agent_name "$workspace_id" idea-center)" ||
     ! worker_1_agent_name="$(_hc_agent_name "$workspace_id" worker-1)" ||
     ! worker_2_agent_name="$(_hc_agent_name "$workspace_id" worker-2)" ||
     ! worker_3_agent_name="$(_hc_agent_name "$workspace_id" worker-3)"; then
    return 1
  fi

  # `agent start` waits for interactive readiness. Put every startup request
  # in its own job so one slow agent cannot delay the others from launching.
  _hc_start_lazygit_and_wait "$lazygit_pane" &
  pids+=("$!")
  _hc_start_agent_and_wait "$worker_1_pane" "$worker_1_agent_name" agy --dangerously-skip-permissions &
  pids+=("$!")
  _hc_start_agent_and_wait "$worker_2_pane" "$worker_2_agent_name" pi &
  pids+=("$!")
  _hc_start_agent_and_wait "$worker_3_pane" "$worker_3_agent_name" pi &
  pids+=("$!")
  _hc_start_agent_and_wait "$claude_pane" "$idea_agent_name" claude --dangerously-skip-permissions --rc &
  pids+=("$!")

  _hc_wait_for_all "${pids[@]}"
}

_hc_bootstrap_cockpit() {
  emulate -L zsh
  local workspace_id="$1"
  local controller_pane="$2"
  local current_agent="$3"
  local lazygit_pane="$4"
  local worker_1_pane="$5"
  local worker_2_pane="$6"
  local worker_3_pane="$7"
  local claude_pane="$8"

  # The caller backgrounds this bootstrap after the layout exists. The
  # current shell is therefore free for pane run to start Codex immediately;
  # readiness checks and every other component can continue independently.
  if [[ -z "$current_agent" ]]; then
    _hc_run_alias "$controller_pane" codexyolo || return 1
  fi

  _hc_wait_for_shells \
    "$lazygit_pane" \
    "$worker_1_pane" \
    "$worker_2_pane" \
    "$worker_3_pane" \
    "$claude_pane" || return 1

  _hc_start_all_components \
    "$workspace_id" \
    "$lazygit_pane" \
    "$worker_1_pane" \
    "$worker_2_pane" \
    "$worker_3_pane" \
    "$claude_pane"
}

_hc_find_existing_cockpit_tab() {
  emulate -L zsh
  local project_cwd="$1"
  local idea_cwd="$2"

  command jq -r --arg project_cwd "$project_cwd" --arg idea_cwd "$idea_cwd" '
    [.result.panes[]] | group_by(.tab_id)
    | map(select(
        (length == 6)
        and ((map(.agent // "") | sort) == ["", "agy", "claude", "codex", "pi", "pi"])
        and ([(.[] | select(
          (.agent // "") == ""
          and (.terminal_title_stripped // "") == "lazygit"
          and ((.cwd // .foreground_cwd // "") == $project_cwd)
        ))] | length == 1)
        and ([(.[] | select(
          (.agent // "") == "claude"
          and ((.cwd // .foreground_cwd // "") == $idea_cwd)
        ))] | length == 1)
        and ([(.[] | select(
          (.agent // "") != "claude"
          and ((.cwd // .foreground_cwd // "") == $project_cwd)
        ))] | length == 5)
      ))
    | .[0][0].tab_id // empty
  '
}

_hc_require_named_agents_available() {
  emulate -L zsh
  local workspace_id="$1"
  local agent_list
  if ! agent_list="$(_hc_call agent list 2>/dev/null)"; then
    print -u2 -- 'hc could not inspect existing Herdr agent names; refusing to create panes.'
    return 1
  fi

  local role agent_name conflict_location
  for role in idea-center worker-1 worker-2 worker-3; do
    if ! agent_name="$(_hc_agent_name "$workspace_id" "$role")"; then
      return 1
    fi
    if ! conflict_location="$(print -r -- "$agent_list" | command jq -c --arg name "$agent_name" '
      [.result.agents[]? | select(.name == $name)
       | {workspace_id, tab_id, pane_id}]
      | .[0] // empty
    ')"; then
      print -u2 -- "hc could not parse the Herdr agent list while checking $agent_name."
      return 1
    fi
    if [[ -n "$conflict_location" ]]; then
      print -u2 -- "Agent name $agent_name is already in use ($conflict_location); refusing to create a duplicate cockpit in workspace $workspace_id."
      return 1
    fi
  done
}

_hc_named_agents_ready() {
  emulate -L zsh
  local workspace_id="$1"
  local role agent_name

  for role in idea-center worker-1 worker-2 worker-3; do
    agent_name="$(_hc_agent_name "$workspace_id" "$role")" || return 1
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

  local idea_cwd="${HOME}/Work/github/idea"
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

  local workspace_id tab_id controller_pane current_agent workspace_namespace
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

  if ! workspace_namespace="$(_hc_workspace_namespace "$workspace_id")"; then
    return 1
  fi

  local workspace_panes tab_pane_count
  if ! workspace_panes="$(_hc_call pane list --workspace "$workspace_id")" ||
     ! tab_pane_count="$(print -r -- "$workspace_panes" | command jq -er --arg tab "$tab_id" \
       '[.result.panes[] | select(.tab_id == $tab)] | length')"; then
    print -u2 -- "hc could not inspect panes in workspace $workspace_id."
    return 1
  fi

  local existing_cockpit_tab
  if ! existing_cockpit_tab="$(print -r -- "$workspace_panes" | \
      _hc_find_existing_cockpit_tab "$cockpit_cwd" "$idea_cwd")"; then
    print -u2 -- 'hc could not inspect existing cockpit layouts in the workspace.'
    return 1
  fi
  if [[ -n "$existing_cockpit_tab" ]]; then
    print -r -- "Herdr cockpit already active in workspace $workspace_id, tab $existing_cockpit_tab, project $cockpit_cwd, idea-center $idea_cwd."
    if [[ "$existing_cockpit_tab" != "$tab_id" ]]; then
      print -r -- "Current tab $tab_id was left untouched; switch to tab $existing_cockpit_tab to use it."
    fi
    return 0
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
    if [[ "$same_cockpit" == true ]] && _hc_named_agents_ready "$workspace_id"; then
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

  _hc_require_named_agents_available "$workspace_id" || return 1

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

  # Keep the current pane responsive so pane run can launch codexyolo first.
  # The helper starts Codex before waiting for or starting any other pane.
  _hc_bootstrap_cockpit \
    "$workspace_id" \
    "$controller_pane" \
    "$current_agent" \
    "$lazygit_pane" \
    "$worker_1_pane" \
    "$worker_2_pane" \
    "$worker_3_pane" \
    "$claude_pane" &!

  print -r -- 'Herdr cockpit layout created; codexyolo is launching first and the other panes are starting in the background.'
  print -r -- "workspace: $workspace_id"
  print -r -- "agent namespace: ${workspace_namespace}-<role>"
  print -r -- "idea-center/claude agent: ${workspace_namespace}-idea-center"
  print -r -- "worker-1/agy agent: ${workspace_namespace}-worker-1"
  print -r -- "worker-2/pi agent: ${workspace_namespace}-worker-2"
  print -r -- "worker-3/pi agent: ${workspace_namespace}-worker-3"
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
