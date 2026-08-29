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

if [ ! -f "$autostart" ]; then
  fail "Required Omarchy Hyprland config is missing: $autostart"
  exit 1
fi
if [ ! -f "$module" ]; then
  fail "Dotfiles Hyprland module is missing: $module"
  exit 1
fi

ensure_symlink "$module" "$target"
if ! grep -Fqx -- "$require_line" "$autostart"; then
  backup_file "$autostart"
fi
ensure_source_line "$autostart" "$require_line"

ok "Sunshine headless display enabled; log out and back in to create HEADLESS-1"
