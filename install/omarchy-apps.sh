#!/usr/bin/env bash
# Install the personal Omarchy workstation application set without managing
# application configuration. All operations are idempotent.
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != omarchy ]; then
  fail "Omarchy applications can only be installed on Omarchy"
  exit 1
fi

info "Ensuring Omarchy workstation applications are installed..."

# Use Omarchy's service installer so a fresh machine also receives the `op` CLI
# and Chromium extension. Avoid reopening 1Password when both packages exist.
if ! pacman -Q 1password 1password-cli >/dev/null 2>&1; then
  omarchy install service 1password
else
  ok "1Password and its CLI already installed"
fi

# Tailscale's Omarchy service installer owns the whole integration: package,
# system daemon, login/up flow, per-user operator permission, Taildrop receiver,
# bar plugin, and admin-console web app. A fresh machine must use that route
# rather than installing only the package.
if ! pacman -Q tailscale >/dev/null 2>&1; then
  omarchy install service tailscale
else
  ok "Tailscale already installed (authentication remains machine-local)"
fi

# Chromium and Obsidian ship as Omarchy base packages. Listing them explicitly
# keeps recovery deterministic if either preinstall was removed. Moonlight is
# part of the remote-desktop workstation profile; its host list and pairing
# data remain outside this repository.
omarchy pkg add btop chromium moonlight-qt obsidian

# Voxtype is more than its package: Omarchy's installer seeds the config,
# downloads a speech model, enables GPU support when possible, installs the user
# service, and reloads the desktop integration. Use that complete path on a
# fresh/incomplete machine; preserve an already configured installation.
if ! has voxtype || [ ! -f "$HOME/.config/voxtype/config.toml" ] || [ ! -d "$HOME/.local/share/voxtype" ]; then
  omarchy voxtype install
else
  ok "Voxtype already installed and configured"
fi

ok "Omarchy workstation applications installed"
