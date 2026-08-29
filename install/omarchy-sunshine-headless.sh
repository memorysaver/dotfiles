#!/usr/bin/env bash
# Opt in to a persistent Hyprland virtual display for a headless Sunshine host.
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != omarchy ]; then
  fail "Sunshine headless setup can only run on Omarchy"
  exit 1
fi

hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
autostart="$hypr_dir/autostart.lua"
module="$DOTFILES_DIR/config/hypr/sunshine_headless.lua"
target="$hypr_dir/sunshine_headless.lua"
require_line='require("hypr.sunshine_headless")'
managed_marker='-- Managed by dotfiles: omarchy-sunshine-headless'

if [ ! -f "$autostart" ]; then
  fail "Required Omarchy Hyprland config is missing: $autostart"
  exit 1
fi
if [ ! -f "$module" ]; then
  fail "Dotfiles Hyprland module is missing: $module"
  exit 1
fi

# Hyprland's Lua config loader is sandboxed and cannot follow a require() to a
# symlink whose target lives outside ~/.config/hypr. Keep a marked, real copy in
# the config directory instead. Older versions of this task created the exact
# repository symlink below; migrate only that known target automatically.
if [ -L "$target" ] && [ "$(readlink "$target")" = "$module" ]; then
  rm "$target"
  cp -- "$module" "$target"
  ok "Migrated sunshine_headless.lua from symlink to a loader-safe copy"
elif [ -f "$target" ] && [ "$(head -n 1 "$target")" = "$managed_marker" ]; then
  cp -- "$module" "$target"
  ok "Updated managed sunshine_headless.lua"
elif [ -e "$target" ] || [ -L "$target" ]; then
  fail "Refusing to replace unmanaged Hyprland config: $target"
  exit 1
else
  cp -- "$module" "$target"
  ok "Installed sunshine_headless.lua"
fi

if ! grep -Fqx -- "$require_line" "$autostart"; then
  backup_file "$autostart"
fi
ensure_source_line "$autostart" "$require_line"

ok "Sunshine headless display enabled; log out and back in to create HEADLESS-1"
