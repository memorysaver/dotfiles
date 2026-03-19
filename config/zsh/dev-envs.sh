#!/usr/bin/env bash
# Tmux development environment helpers
# Sourced by .zshrc

# Modular tmux development environment
_create_dev_tmux_session() {
  local ai_tool_command="$1"
  local ai_tool_name="${2:-AI}"
  local session_name="${3:-$(basename "$(pwd)" | sed 's/[^a-zA-Z0-9]/_/g')}"

  tmux kill-session -t "$session_name" 2>/dev/null

  tmux new-session -d -s "$session_name" -c "$(pwd)"
  tmux split-window -h -c "$(pwd)"
  tmux select-pane -t "$session_name.0"
  tmux split-window -v -c "$(pwd)"

  sleep 0.1
  tmux resize-pane -t "$session_name.0" -x 55%
  tmux resize-pane -t "$session_name.0" -y 50%
  tmux resize-pane -t "$session_name.1" -y 50%
  tmux resize-pane -t "$session_name.2" -x 45%

  tmux send-keys -t "$session_name.0" 'lazygit' Enter
  tmux send-keys -t "$session_name.1" 'opencode' Enter
  tmux send-keys -t "$session_name.2" "$ai_tool_command" Enter

  tmux select-pane -t "$session_name.2"
  tmux attach-session -t "$session_name"
}

# Claude Code dev environment
ccdev() {
  _create_dev_tmux_session "claude --dangerously-skip-permissions" "Claude" "$1"
}

# OpenCode dev environment
opendev() {
  _create_dev_tmux_session "opencode" "OpenCode" "$1"
}

# Codex dev environment
codexdev() {
  if [[ -z "$1" ]]; then
    _create_dev_tmux_session "codex -m gpt-5-codex -c model_reasoning_effort=\"high\" -c model_reasoning_summary_format=experimental --search --dangerously-bypass-approvals-and-sandbox" "Codex-Enhanced"
  else
    _create_dev_tmux_session "codex --profile \"$1\" -c model_reasoning_effort=\"high\" -c model_reasoning_summary_format=experimental --search --dangerously-bypass-approvals-and-sandbox" "Codex-Enhanced" "$1"
  fi
}
