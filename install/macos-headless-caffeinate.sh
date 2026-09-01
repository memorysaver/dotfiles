#!/usr/bin/env bash
# Opt in to a persistent caffeinate assertion for a macOS headless session.
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != macos ]; then
  fail "This recipe can only run on macOS"
  exit 1
fi

action="${1:-enable}"
label="com.memorysaver.macos-headless-caffeinate"
source_plist="$DOTFILES_DIR/config/macos/launchagents/$label.plist"
target_dir="$HOME/Library/LaunchAgents"
target="$target_dir/$label.plist"
domain="gui/$(id -u)"
managed_marker='<!-- Managed by dotfiles: macos-headless-caffeinate -->'

if [ ! -f "$source_plist" ]; then
  fail "Dotfiles LaunchAgent is missing: $source_plist"
  exit 1
fi

is_managed() {
  [ -f "$target" ] && grep -Fqx -- "$managed_marker" "$target"
}

enable() {
  plutil -lint "$source_plist" >/dev/null
  ensure_dir "$target_dir"

  # Keep a real copy in LaunchAgents so launchd does not depend on a mutable
  # repository path. Only replace a file carrying our exact marker.
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source_plist" ]; then
    rm "$target"
    cp -- "$source_plist" "$target"
    ok "Migrated the managed LaunchAgent symlink to a real file"
  elif [ -f "$target" ] && is_managed; then
    cp -- "$source_plist" "$target"
    ok "Updated the managed LaunchAgent"
  elif [ -e "$target" ] || [ -L "$target" ]; then
    fail "Refusing to replace unmanaged LaunchAgent: $target"
    exit 1
  else
    cp -- "$source_plist" "$target"
    ok "Installed $target"
  fi
  chmod 0644 "$target"
  plutil -lint "$target" >/dev/null

  # Reload the exact user job so rerunning the recipe applies plist changes.
  launchctl bootout "$domain/$label" 2>/dev/null || true
  launchctl bootstrap "$domain" "$target"
  launchctl print "$domain/$label" >/dev/null
  ok "Loaded $label"
  warn "This prevents idle sleep on battery too; disable it when headless mode is not needed"
}

disable() {
  launchctl bootout "$domain/$label" 2>/dev/null || true
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    ok "$label is already disabled"
    return 0
  fi
  if ! is_managed; then
    fail "Refusing to remove unmanaged LaunchAgent: $target"
    exit 1
  fi
  rm "$target"
  ok "Removed managed LaunchAgent $target"
}

case "$action" in
  enable) enable ;;
  disable) disable ;;
  *)
    fail "Usage: $0 [enable|disable]"
    exit 2
    ;;
esac
