#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_home="$(mktemp -d /tmp/dotfiles-omarchy-test.XXXXXX)"
test_bin="$(mktemp -d /tmp/dotfiles-omarchy-bin.XXXXXX)"
trap 'rm -rf "$test_home" "$test_bin"' EXIT

# The installer only needs to see a Moonlight executable; do not install or
# launch the real client during a smoke test.
printf '#!/usr/bin/env bash\nexit 0\n' >"$test_bin/moonlight"
chmod +x "$test_bin/moonlight"
printf '#!/usr/bin/env bash\nexit 1\n' >"$test_bin/pgrep"
chmod +x "$test_bin/pgrep"

config_dir="$test_home/.config/Moonlight Game Streaming Project"
mkdir -p "$config_dir"
printf '%s\n' '[General]' 'capturesyskeys=1' 'windowmode=1' '[Hosts]' 'pairing-secret=keep-me' >"$config_dir/Moonlight.conf"

HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  DOTFILES_PLATFORM=omarchy PATH="$test_bin:$PATH" \
  bash "$repo_root/install/omarchy-moonlight.sh" >/dev/null

grep -Fqx 'capturesyskeys=2' "$config_dir/Moonlight.conf"
grep -Fqx 'windowmode=1' "$config_dir/Moonlight.conf"
grep -Fqx 'pairing-secret=keep-me' "$config_dir/Moonlight.conf"
[ "$(find "$config_dir" -maxdepth 1 -name 'Moonlight.conf.pre-dotfiles.*' | wc -l)" -eq 1 ]

# Running it again is idempotent and does not create another backup.
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  DOTFILES_PLATFORM=omarchy PATH="$test_bin:$PATH" \
  bash "$repo_root/install/omarchy-moonlight.sh" >/dev/null
[ "$(find "$config_dir" -maxdepth 1 -name 'Moonlight.conf.pre-dotfiles.*' | wc -l)" -eq 1 ]

# Exercise the additive Hyprland link path in an isolated HOME.
printf '%s\n' '# host bashrc' >"$test_home/.bashrc"
mkdir -p "$test_home/.config/hypr"
printf '%s\n' '-- host bindings' >"$test_home/.config/hypr/bindings.lua"
ln -s "$repo_root" "$test_home/.dotfiles"

HOME="$test_home" DOTFILES_PLATFORM=omarchy just link >/dev/null
[ -L "$test_home/.config/hypr/remote_desktop.lua" ]
[ "$(grep -Fxc 'require("hypr.remote_desktop")' "$test_home/.config/hypr/bindings.lua")" -eq 1 ]

HOME="$test_home" DOTFILES_PLATFORM=omarchy just link >/dev/null
[ "$(grep -Fxc 'require("hypr.remote_desktop")' "$test_home/.config/hypr/bindings.lua")" -eq 1 ]

if command -v luac >/dev/null 2>&1; then
  luac -p "$repo_root/config/hypr/remote_desktop.lua"
fi

# The Sunshine host setup is separately opt-in and remains additive.
printf '%s\n' '-- host autostart' >"$test_home/.config/hypr/autostart.lua"
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  DOTFILES_DIR="$repo_root" DOTFILES_PLATFORM=omarchy \
  bash "$repo_root/install/omarchy-sunshine-headless.sh" >/dev/null
[ -L "$test_home/.config/hypr/sunshine_headless.lua" ]
[ "$(grep -Fxc 'require("hypr.sunshine_headless")' "$test_home/.config/hypr/autostart.lua")" -eq 1 ]

# Re-running the opt-in task is idempotent.
HOME="$test_home" XDG_CONFIG_HOME="$test_home/.config" \
  DOTFILES_DIR="$repo_root" DOTFILES_PLATFORM=omarchy \
  bash "$repo_root/install/omarchy-sunshine-headless.sh" >/dev/null
[ "$(grep -Fxc 'require("hypr.sunshine_headless")' "$test_home/.config/hypr/autostart.lua")" -eq 1 ]

if command -v luac >/dev/null 2>&1; then
  luac -p "$repo_root/config/hypr/sunshine_headless.lua"
fi

echo "Omarchy remote-desktop smoke test passed"
