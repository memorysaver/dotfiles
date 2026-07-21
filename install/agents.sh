#!/usr/bin/env bash
# Install / upgrade AI coding agents: Claude Code, Codex, OpenCode, agy, Pi
# Usage:
#   agents.sh            install anything missing (idempotent)
#   agents.sh --upgrade  force every agent to its latest release
source "$(dirname "$0")/../lib/helpers.sh"

UPGRADE=0
[ "${1:-}" = "--upgrade" ] && UPGRADE=1
if [ "$UPGRADE" = 1 ]; then VERB="Upgrading"; else VERB="Installing"; fi

if [ "$UPGRADE" = 1 ]; then
  info "Upgrading AI coding agents to latest..."
else
  info "Installing AI coding agents..."
fi

PI_NPM_PACKAGE="${PI_NPM_PACKAGE:-@mariozechner/pi}"
PI_AGENT_BIN="${PI_AGENT_BIN:-pi}"
PI_ALT_BIN="${PI_ALT_BIN:-pi-agent}"

# Do we need to install/upgrade <cmd>? Yes in upgrade mode, or if it's missing.
should_setup() {
  [ "$UPGRADE" = 1 ] && return 0
  has "$1" && return 1
  return 0
}

# --- Claude Code --- (curl installer is idempotent and upgrades in place)
if should_setup claude; then
  info "$VERB Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
else
  ok "Claude Code already installed"
fi

# --- OpenAI Codex CLI ---
# Install via the official standalone installer, NEVER bun/npm. It downloads a
# self-contained native binary from GitHub Releases into ~/.codex/packages/ and
# symlinks ~/.local/bin/codex — independent of Node/Homebrew, so it cannot hit
# the bun bug where the vendored binary goes missing (`spawn ... codex ENOENT`).
# Re-running the installer upgrades in place. ~/.local/bin is already on PATH
# ahead of /opt/homebrew/bin (config/zsh/.zshrc), so CODEX_NON_INTERACTIVE keeps
# it from prompting or editing any shell profile; PATH order shadows older copies.
if has codex && codex --version >/dev/null 2>&1 && [ "$UPGRADE" != 1 ]; then
  ok "Codex CLI already installed ($(codex --version 2>/dev/null))"
else
  if has codex && ! codex --version >/dev/null 2>&1; then
    warn "Codex CLI present but not runnable — reinstalling"
  fi
  info "$VERB Codex CLI..."
  CODEX_NON_INTERACTIVE=1 curl -fsSL https://chatgpt.com/codex/install.sh | sh
fi

# --- OpenCode --- (curl installer is idempotent and upgrades in place)
if should_setup opencode; then
  info "$VERB OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
else
  ok "OpenCode already installed"
fi

# --- Antigravity CLI (agy) --- (curl installer is idempotent and upgrades in place)
if should_setup agy; then
  info "$VERB Antigravity CLI..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || warn "agy install failed"
else
  ok "Antigravity CLI already installed"
fi

# --- Pi Coding Agent ---
if [ "$UPGRADE" != 1 ] && { has "$PI_AGENT_BIN" || has "$PI_ALT_BIN"; }; then
  ok "Pi already installed"
elif has npm; then
  info "$VERB Pi coding agent..."
  npm install -g "$PI_NPM_PACKAGE"
else
  warn "npm not found — skipping Pi"
fi

# --- UI/UX Pro Max Skills ---
if should_setup uipro; then
  if has npm; then
    info "$VERB uipro-cli..."
    npm install -g uipro-cli
  else
    warn "npm not found — skipping uipro-cli"
  fi
fi
if has uipro; then
  info "Installing UI/UX Pro Max skills to ~/.claude/skills/..."
  # Must run from $HOME so it installs to ~/.claude/skills/
  (cd "$HOME" && uipro init --ai claude --offline)
fi

if [ "$UPGRADE" = 1 ]; then
  ok "AI coding agents upgraded"
else
  ok "AI coding agents installation complete"
fi
