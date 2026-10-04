#!/usr/bin/env bash
# Grok Bot Debian sandbox overlay.
#
# Shared tools come from `just _setup`. This script records the recipe scope so
# we can tell what was intentionally applied on the Cursor/Grok agent host,
# keeps desktop/mail/Omarchy-only pieces out of the path, and installs the few
# grok-bot-only packages: openssh-client, Tailscale, and QMD.
#
# This recipe does not install Dagu (it may already exist on the host). grok-bot
# scheduling uses Grok Bot routines (server-side saved prompts on cron/events).
source "$(dirname "$0")/../lib/helpers.sh"

if [ "$DOTFILES_PLATFORM" != grok-bot ]; then
  fail "grok-bot overlay is for grok-bot, but detected $DOTFILES_PLATFORM"
  exit 1
fi

info "Applying Grok Bot sandbox overlay..."
info "Includes: workspace, core, runtimes, agents, tools (incl. hyperframes), seed-agents, link, doctor"
info "Grok-bot only: openssh-client, tailscale, qmd"
info "Skips: omarchy-apps, Moonlight/Hypr, Himalaya/Ortie, Ghostty, macOS headless helpers"

ensure_dir "$HOME/.config/dotfiles"

stamp="$HOME/.config/dotfiles/grok-bot-recipe"
cat >"$stamp" <<'STAMP'
# Managed by dotfiles: just setup-grok-bot / install/grok-bot.sh
platform=grok-bot
base=debian
includes=workspace,core,runtimes,agents,tools,seed-agents,link,doctor
extras=openssh-client,tailscale,qmd
excludes=omarchy-apps,omarchy-moonlight,hypr,himalaya,ortie,ghostty,macos-headless
STAMP
ok "Recipe stamp: $stamp"

# --- openssh-client ---
# A sandbox update once left the box without `ssh`; git-over-ssh, `herdr
# --remote` and Tailscale SSH clients all need it.
ensure_installed ssh openssh openssh-client

# --- Tailscale ---
# Omarchy owns Tailscale via omarchy-apps; this Debian sandbox installs it here so
# Update Computer restores the CLI. The official script adds Tailscale's apt
# repository and installs the `tailscale` package. Auth and `tailscale set --ssh`
# stay machine-local (no secrets in git). The sandbox has no systemd, so the
# daemon is not started for you -- start it by hand, then log in:
#   sudo tailscaled --state=/var/lib/tailscale/tailscaled.state \
#     --socket=/var/run/tailscale/tailscaled.sock >/tmp/tailscaled.log 2>&1 &
#   sudo tailscale up
if has tailscale; then
  ok "tailscale already installed ($(tailscale version 2>/dev/null | head -1))"
else
  info "Installing Tailscale (apt repo via tailscale.com/install.sh)..."
  if curl -fsSL https://tailscale.com/install.sh | sh; then
    ok "tailscale installed ($(tailscale version 2>/dev/null | head -1))"
  else
    warn "Tailscale install failed"
  fi
fi
if has tailscale && ! pgrep -x tailscaled >/dev/null 2>&1; then
  warn "tailscaled is not running (no systemd) -- start it manually, then: sudo tailscale up"
fi

# --- QMD (grok-bot only) ---
# docs/removed-agent-clis.md records why qmd is no longer installed globally on
# every machine. grok-bot still uses it, so it is installed here and nowhere else.
# Native modules need a compiler toolchain.
if dpkg -s build-essential >/dev/null 2>&1; then
  ok "build-essential already installed"
else
  info "Installing build-essential..."
  sudo apt-get install -y build-essential || warn "build-essential install failed"
fi
if ! has bun && [ -x "$HOME/.bun/bin/bun" ]; then
  export PATH="$HOME/.bun/bin:$PATH"
fi
if ! has bun; then
  info "Installing Bun (needed for qmd)..."
  curl -fsSL https://bun.sh/install | bash || warn "Bun install failed"
  export PATH="$HOME/.bun/bin:$PATH"
fi
if ! has bun; then
  warn "bun not found -- skipping qmd"
elif [ -x "$HOME/.bun/bin/qmd" ]; then
  ok "qmd already installed"
else
  info "Installing qmd (bun install -g @tobilu/qmd)..."
  bun install -g @tobilu/qmd || warn "qmd install failed"
fi
if [ -x "$HOME/.bun/bin/qmd" ]; then
  ensure_symlink "$HOME/.bun/bin/qmd" "$HOME/.local/bin/qmd" || warn "qmd link not created"
fi

ok "Grok Bot overlay complete"
