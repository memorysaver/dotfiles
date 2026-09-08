#!/usr/bin/env bash
# Create the shared workspace skeleton and install its agent navigation policy.
# Existing projects are never moved by this script.
source "$(dirname "$0")/../lib/helpers.sh"

source "$DOTFILES_DIR/lib/workspace.sh"
workspace_root="${WORKSPACE_ROOT:-$HOME/Work}"
rule_source="$(workspace_rule_source)"

info "Preparing shared workspace..."

ensure_dir "$workspace_root"
ensure_dir "$workspace_root/github"
ensure_dir "$workspace_root/cowork"
ensure_dir "$workspace_root/tries"
ensure_symlink "$DOTFILES_DIR/config/workspace/AGENTS.md" "$workspace_root/AGENTS.md"
workspace_link_rule "$rule_source" "$workspace_root/orchestration-rules"

ensure_symlink "$DOTFILES_DIR/config/workspace/README.md" "$workspace_root/README.md"
workspace_remove_legacy_rules "$workspace_root" "$rule_source"

ok "Shared workspace ready at $workspace_root"
