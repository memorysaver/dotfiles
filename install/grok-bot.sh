#!/usr/bin/env bash
# Grok Bot Debian sandbox overlay.
#
# Shared tools come from `just _setup`. This script records the recipe scope so
# we can tell what was intentionally applied on the Cursor/Grok agent host, and
# keeps desktop/mail/Omarchy-only pieces out of the path.
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != grok-bot ]; then
  fail "grok-bot overlay is for grok-bot, but detected $DOTFILES_PLATFORM"
  exit 1
fi

info "Applying Grok Bot sandbox overlay..."
info "Includes: workspace, core, runtimes, agents, tools, seed-agents, link, doctor"
info "Skips: omarchy-apps, Moonlight/Hypr, Himalaya/Ortie, Ghostty, macOS headless helpers"

ensure_dir "$HOME/.config/dotfiles"

stamp="$HOME/.config/dotfiles/grok-bot-recipe"
cat >"$stamp" <<'STAMP'
# Managed by dotfiles: just setup-grok-bot / install/grok-bot.sh
platform=grok-bot
base=debian
includes=workspace,core,runtimes,agents,tools,seed-agents,link,doctor
excludes=omarchy-apps,omarchy-moonlight,hypr,himalaya,ortie,ghostty,macos-headless
STAMP
ok "Recipe stamp: $stamp"

ok "Grok Bot overlay complete"
