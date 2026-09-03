#!/usr/bin/env bash
# Create the shared workspace skeleton and install its agent navigation policy.
# Existing projects are never moved by this script.
source "$(dirname "$0")/../lib/helpers.sh"

workspace_root="$HOME/Work"

info "Preparing shared workspace..."

ensure_dir "$workspace_root"
ensure_dir "$workspace_root/github"
ensure_dir "$workspace_root/cowork"
ensure_dir "$workspace_root/tries"
ensure_symlink "$DOTFILES_DIR/config/workspace/AGENTS.md" "$workspace_root/AGENTS.md"

ok "Shared workspace ready at $workspace_root"
