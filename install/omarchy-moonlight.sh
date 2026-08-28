#!/usr/bin/env bash
# Configure the one Moonlight preference required by the Hyprland remote
# desktop integration.  Only capturesyskeys is managed; host entries, pairing
# keys, and every other Moonlight preference remain machine-local.
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != omarchy ]; then
  fail "Moonlight remote-desktop setup can only run on Omarchy"
  exit 1
fi

if ! has moonlight; then
  warn "Moonlight is not installed; skipping system-shortcut capture setup"
  exit 0
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Moonlight Game Streaming Project"
config="$config_dir/Moonlight.conf"

# QSettings can overwrite the file while Moonlight is open. Leave a running
# client alone and let the user rerun `just omarchy-moonlight` after closing it.
if command -v pgrep >/dev/null 2>&1 && pgrep -x moonlight >/dev/null 2>&1; then
  warn "Moonlight is running; close it and rerun just omarchy-moonlight"
  exit 0
fi

ensure_dir "$config_dir"

if [ ! -e "$config" ] && [ ! -L "$config" ]; then
  # A minimal QSettings file is enough; Moonlight will add its other defaults
  # on first launch. Keep a newly-created file private before pairing data can
  # be written into it.
  (
    umask 077
    printf '%s\n' '[General]' 'capturesyskeys=2' >"$config"
  )
  ok "Created Moonlight config with Capture system keyboard shortcuts = Always"
  exit 0
fi

current="$(awk '
  BEGIN { in_general = 0 }
  /^\[[^]]+\][[:space:]]*$/ {
    in_general = (tolower($0) ~ /^\[general\][[:space:]]*$/)
    next
  }
  in_general && $0 ~ /^[[:space:]]*capturesyskeys[[:space:]]*=/ {
    value = $0
    sub(/^[^=]*=/, "", value)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    print value
    exit
  }
' "$config")"

if [ "$current" = 2 ]; then
  ok "Moonlight Capture system keyboard shortcuts already set to Always"
  exit 0
fi

backup_file "$config"
tmp="$(mktemp "${config}.dotfiles.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT
chmod --reference="$config" "$tmp" 2>/dev/null || true

awk '
  BEGIN {
    in_general = 0
    saw_general = 0
    replaced = 0
    inserted = 0
  }
  function insert_key() {
    if (!replaced && !inserted) {
      print "capturesyskeys=2"
      inserted = 1
    }
  }
  /^\[[^]]+\][[:space:]]*$/ {
    if (in_general) {
      insert_key()
    }
    in_general = (tolower($0) ~ /^\[general\][[:space:]]*$/)
    if (in_general) {
      saw_general = 1
    }
    print
    next
  }
  in_general && $0 ~ /^[[:space:]]*capturesyskeys[[:space:]]*=/ {
    if (!replaced) {
      print "capturesyskeys=2"
      replaced = 1
    }
    next
  }
  { print }
  END {
    if (in_general) {
      insert_key()
    }
    if (!saw_general) {
      print ""
      print "[General]"
      print "capturesyskeys=2"
    }
  }
' "$config" >"$tmp"
mv "$tmp" "$config"
trap - EXIT
ok "Set Moonlight Capture system keyboard shortcuts = Always"
