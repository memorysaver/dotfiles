#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

actual="$(bash -c 'source "$1/lib/helpers.sh"; printf "%s" "$DOTFILES_PLATFORM"' _ "$repo_root")"
[ -n "$actual" ] || { echo "platform detection returned empty" >&2; exit 1; }

for platform in macos omarchy arch debian; do
  detected="$(DOTFILES_PLATFORM="$platform" bash -c 'source "$1/lib/helpers.sh"; printf "%s" "$DOTFILES_PLATFORM"' _ "$repo_root")"
  [ "$detected" = "$platform" ] || {
    echo "platform override failed: expected $platform, got $detected" >&2
    exit 1
  }
done

rg -F '@just omarchy-apps' "$repo_root/justfile" >/dev/null
rg -F '@just omarchy-moonlight' "$repo_root/justfile" >/dev/null
rg -F '@just link' "$repo_root/justfile" >/dev/null
rg -F '@just doctor' "$repo_root/justfile" >/dev/null
rg -F 'omarchy install service 1password' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'omarchy pkg add btop chromium moonlight-qt obsidian voxtype-bin' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'config/hypr/remote_desktop.lua' "$repo_root/justfile" >/dev/null
rg -F 'no_shortcuts_inhibit = true' "$repo_root/config/hypr/remote_desktop.lua" >/dev/null
rg -F 'capturesyskeys=2' "$repo_root/install/omarchy-moonlight.sh" >/dev/null
rg -F 'moonlight obsidian voxtype' "$repo_root/tools/doctor.sh" >/dev/null
rg -F 'Moonlight remote-desktop mode' "$repo_root/tools/doctor.sh" >/dev/null
rg -F 'npx --yes skills@1.5.20 add' "$repo_root/install/agents.sh" >/dev/null
rg -F 'retry 3 5 mise use --global' "$repo_root/install/runtimes.sh" >/dev/null

echo "platform smoke test passed (host: $actual)"
