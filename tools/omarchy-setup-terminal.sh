#!/usr/bin/env bash
# Launch the normal Omarchy setup recipe in a visible terminal for sudo input.
set -euo pipefail

source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != omarchy ]; then
  fail "This launcher is only available on Omarchy"
  exit 1
fi

if ! command -v omarchy >/dev/null 2>&1; then
  fail "omarchy command not found"
  exit 1
fi

if [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
  fail "No graphical session found"
  printf 'Run this from a terminal instead: cd %q && just setup-omarchy\n' "$DOTFILES_DIR" >&2
  exit 1
fi

printf -v quoted_dir '%q' "$DOTFILES_DIR"
omarchy launch terminal bash -lc \
  "cd $quoted_dir && just setup-omarchy; setup_status=\$?; printf '\\n'; if [ \$setup_status -eq 0 ]; then echo 'Dotfiles setup complete. You can close this terminal.'; else echo \"Dotfiles setup stopped or failed with status \$setup_status.\"; fi; exec bash"

ok "Opened Omarchy setup in a visible terminal"
