#!/usr/bin/env bash
# Create the shared workspace skeleton and install its agent navigation policy.
# Existing projects are never moved by this script.
source "$(dirname "$0")/../lib/helpers.sh"

workspace_root="$HOME/Work"
legacy_github="$HOME/Documents/github"

info "Preparing shared workspace..."

ensure_dir "$workspace_root"
ensure_dir "$workspace_root/github"
ensure_dir "$workspace_root/cowork"
ensure_dir "$workspace_root/tries"
ensure_symlink "$DOTFILES_DIR/config/workspace/AGENTS.md" "$workspace_root/AGENTS.md"

if [ -d "$HOME/Documents" ] && ! ls "$HOME/Documents" >/dev/null 2>&1; then
  warn "Cannot inspect $HOME/Documents from this process; no legacy migration was attempted."
elif [ -d "$legacy_github" ]; then
  legacy_real="$(cd "$legacy_github" && pwd -P)"
  workspace_real="$(cd "$workspace_root/github" && pwd -P)"
  if [ "$legacy_real" != "$workspace_real" ]; then
    warn "Legacy GitHub workspace detected: $legacy_github"
    warn "No projects were moved. Inspect repositories, dirty worktrees, symlinks, and name collisions first."
    warn "After review, migrate repositories individually into $workspace_root/github."
  fi
fi

ok "Shared workspace ready at $workspace_root"
