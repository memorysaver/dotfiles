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

# Chromium and Obsidian normally ship with Omarchy. Listing them explicitly
# keeps recovery deterministic if the preinstall set changes or was removed.
omarchy pkg add chromium obsidian voxtype-bin

ok "Omarchy workstation applications installed"
