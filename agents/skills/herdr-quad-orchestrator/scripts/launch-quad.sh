#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: launch-quad.sh [--cwd PATH] [--label TEXT] [--session NAME] [--startup-timeout MS]

Create a new Herdr workspace with four agent panes:
  top-left     codex --yolo
  top-right    claude --dangerously-skip-permissions --rc (ccyolo)
  bottom-left  agy
  bottom-right pi
USAGE
}

quad_cwd="$PWD"
quad_label=""
quad_session=""
startup_timeout="60000"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --cwd)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      quad_cwd="$2"
      shift 2
      ;;
    --label)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      quad_label="$2"
      shift 2
      ;;
    --session)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      quad_session="$2"
      shift 2
      ;;
    --startup-timeout)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      startup_timeout="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${HERDR_ENV:-}" != 1 ]; then
  printf '%s\n' 'Not running inside a Herdr-managed pane (HERDR_ENV=1 is required).' >&2
  exit 1
fi

quad_cwd="$(cd "$quad_cwd" && pwd -P)"
[ -n "$quad_label" ] || quad_label="herdr-quad:$(basename "$quad_cwd")"

for required_command in herdr jq codex claude agy pi; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$required_command" >&2
    exit 1
  fi
done

herdr_call() {
  if [ "${HERDR_ENV:-}" != 1 ]; then
    printf '%s\n' 'HERDR_ENV changed while launching; refusing further Herdr control.' >&2
    exit 1
  fi
  if [ -n "$quad_session" ]; then
    herdr --session "$quad_session" "$@"
  else
    herdr "$@"
  fi
}

created_workspace="$(herdr_call workspace create --cwd "$quad_cwd" --label "$quad_label" --no-focus)"
root_pane="$(printf '%s\n' "$created_workspace" | jq -er '.result.root_pane.pane_id')"

top_right_split="$(herdr_call pane split "$root_pane" --direction right --cwd "$quad_cwd" --no-focus)"
top_right_pane="$(printf '%s\n' "$top_right_split" | jq -er '.result.pane.pane_id')"

bottom_left_split="$(herdr_call pane split "$root_pane" --direction down --cwd "$quad_cwd" --no-focus)"
bottom_left_pane="$(printf '%s\n' "$bottom_left_split" | jq -er '.result.pane.pane_id')"

bottom_right_split="$(herdr_call pane split "$top_right_pane" --direction down --cwd "$quad_cwd" --no-focus)"
bottom_right_pane="$(printf '%s\n' "$bottom_right_split" | jq -er '.result.pane.pane_id')"

herdr_call agent start controller \
  --kind codex \
  --pane "$root_pane" \
  --timeout "$startup_timeout" \
  -- \
  --yolo

herdr_call agent start claude-yolo \
  --kind claude \
  --pane "$top_right_pane" \
  --timeout "$startup_timeout" \
  -- \
  --dangerously-skip-permissions \
  --rc

herdr_call agent start agy \
  --kind agy \
  --pane "$bottom_left_pane" \
  --timeout "$startup_timeout"

herdr_call agent start pi \
  --kind pi \
  --pane "$bottom_right_pane" \
  --timeout "$startup_timeout"

cat <<REPORT
Herdr quad started without sending task prompts.
workspace label: $quad_label
cwd: $quad_cwd
top-left controller: $root_pane
top-right claude-yolo: $top_right_pane
bottom-left agy: $bottom_left_pane
bottom-right pi: $bottom_right_pane
REPORT
