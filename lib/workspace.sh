#!/usr/bin/env bash
# Source after helpers.sh. Identity is local; host records are private.
workspace_identity_file() {
  printf '%s\n' "${WORKSPACE_ID_FILE:-$HOME/.config/dotfiles/computer-id}"
}

workspace_rule_source() {
  local id_file id="${1:-}" hosts profile
  id_file="$(workspace_identity_file)"
  if [ -z "$id" ] && { [ -e "$id_file" ] || [ -L "$id_file" ]; }; then
    [ -f "$id_file" ] && [ ! -L "$id_file" ] || { fail "Computer identity must be a local regular file"; return 1; }
    id="$(cat "$id_file")"
    [ -n "$id" ] || { fail "Empty computer identity: $id_file"; return 1; }
  fi
  if [ -z "$id" ]; then
    printf '%s\n' "$DOTFILES_DIR/config/workspace/computer-rule"
    return
  fi
  case "$id" in
    *[!a-z0-9-]*|-*|*-|'') fail "Invalid computer ID"; return 1 ;;
  esac
  hosts="${WORKSPACE_HOSTS_DIR:-$HOME/idea/private-config/computers}"
  [ -f "$hosts/$id/computer-rule/README.md" ] && [ -f "$hosts/$id/computer-rule/profile" ] || {
    fail "Selected computer rules unavailable; sync the private host records first"; return 1;
  }
  profile="$(cat "$hosts/$id/computer-rule/profile")"
  case "$DOTFILES_PLATFORM:$profile" in
    macos:mac|omarchy:omarchy-server|omarchy:omarchy-desktop) ;;
    *) fail "Selected computer profile does not match this platform"; return 1 ;;
  esac
  printf '%s\n' "$hosts/$id/computer-rule"
}

workspace_link_rule() {
  local source="$1" target="$2"
  # Upgrade only the old public link. Foreign links and real directories remain protected.
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$DOTFILES_DIR/config/workspace/computer-rule" ] &&
      [ "$source" != "$DOTFILES_DIR/config/workspace/computer-rule" ]; then
    rm "$target"
  fi
  ensure_symlink "$source" "$target"
}
