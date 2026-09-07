#!/usr/bin/env bash
# Bind this computer once; subsequent workspace syncs reuse the local identity.
source "$(dirname "$0")/../lib/helpers.sh"
source "$DOTFILES_DIR/lib/workspace.sh"
[ "$#" -eq 1 ] && [ -n "$1" ] || { fail "Usage: just workspace-computer <computer-id>"; exit 1; }
id_file="$(workspace_identity_file)"
if [ -e "$id_file" ] || [ -L "$id_file" ]; then
  [ -f "$id_file" ] && [ ! -L "$id_file" ] || { fail "Identity must be a local regular file"; exit 1; }
  [ "$(cat "$id_file")" = "$1" ] || { fail "Computer is already bound to another ID; review the local identity before changing it"; exit 1; }
fi
rule_source="$(workspace_rule_source "$1")"
target="${WORKSPACE_ROOT:-$HOME/Work}/computer-rule"
if [ -e "$target" ] || [ -L "$target" ]; then
  [ -L "$target" ] && { [ "$(readlink "$target")" = "$DOTFILES_DIR/config/workspace/computer-rule" ] ||
    [ "$(readlink "$target")" = "$rule_source" ]; } || { fail "Preserving conflicting computer-rule path"; exit 1; }
fi
ensure_dir "$(dirname "$id_file")"
tmp_id="$(mktemp "${id_file}.XXXXXX")"
trap 'rm -f "$tmp_id"' EXIT
printf '%s\n' "$1" > "$tmp_id"
chmod 600 "$tmp_id"
workspace_link_rule "$rule_source" "$target"
mv "$tmp_id" "$id_file"
ok "Computer identity selected; future workspace syncs reuse its private rules"
