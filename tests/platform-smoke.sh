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
rg -F 'omarchy-sunshine-headless:' "$repo_root/justfile" >/dev/null
rg -F '@just link' "$repo_root/justfile" >/dev/null
rg -F '@just doctor' "$repo_root/justfile" >/dev/null
rg -F 'omarchy install service 1password' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'omarchy install service tailscale' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'omarchy pkg add btop chromium moonlight-qt obsidian' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'omarchy voxtype install' "$repo_root/install/omarchy-apps.sh" >/dev/null
rg -F 'config/hypr/remote_desktop.lua' "$repo_root/justfile" >/dev/null
rg -F 'no_shortcuts_inhibit = true' "$repo_root/config/hypr/remote_desktop.lua" >/dev/null
rg -F 'capturesyskeys=2' "$repo_root/install/omarchy-moonlight.sh" >/dev/null
rg -F 'hyprctl output create headless' "$repo_root/config/hypr/sunshine_headless.lua" >/dev/null
rg -F 'mode = "1920x1200@60"' "$repo_root/config/hypr/sunshine_headless.lua" >/dev/null
rg -F 'scale = 1.25' "$repo_root/config/hypr/sunshine_headless.lua" >/dev/null
rg -F 'tailscale btop chromium moonlight obsidian voxtype' "$repo_root/tools/doctor.sh" >/dev/null
rg -F 'Moonlight remote-desktop mode' "$repo_root/tools/doctor.sh" >/dev/null
rg -F 'npx --yes skills@1.5.20 add' "$repo_root/install/agents.sh" >/dev/null
rg -F 'mise use --global node@latest' "$repo_root/install/runtimes.sh" >/dev/null
rg -F 'omarchy-mise-install claude' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy-mise-install codex' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy-mise-install opencode' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy-mise-install npm:@xai-official/grok grok' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy-mise-install pi' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy-mise-install gh' "$repo_root/install/tools.sh" >/dev/null
rg -F 'omarchy pkg add himalaya' "$repo_root/install/tools.sh" >/dev/null
rg -F 'omarchy-mise-install cargo:ortie ortie' "$repo_root/install/tools.sh" >/dev/null
rg -F 'config/ortie/config.toml' "$repo_root/justfile" >/dev/null
rg -F 'config/himalaya/config.toml' "$repo_root/justfile" >/dev/null
rg -F 'tools/browser-open:$$PATH' "$repo_root/justfile" >/dev/null
rg -F 'omarchy) omarchy pkg add herdr' "$repo_root/install/agents.sh" >/dev/null
rg -F 'omarchy) omarchy pkg add terraform' "$repo_root/install/infra.sh" >/dev/null
rg -F 'omarchy) omarchy pkg add pulumi' "$repo_root/install/infra.sh" >/dev/null

echo "platform smoke test passed (host: $actual)"
