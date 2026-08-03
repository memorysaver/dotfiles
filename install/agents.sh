#!/usr/bin/env bash
# Install / upgrade Herdr plus the AI coding agents that run inside it:
# Claude Code, Codex, OpenCode, agy, Pi
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

# --- Herdr --- the multiplexer the agents below run inside
# In homebrew-core, so no tap. Linux has no formula; the official installer drops a
# static binary in ~/.local/bin and re-running it upgrades in place.
# Deliberately NOT using should_setup: it returns true in upgrade mode, which would send
# us down the `brew install` path, where an already-installed formula is a no-op warning
# and the upgrade silently never happens. The curl-based agents below are safe with
# should_setup because their installers upgrade in place; brew's does not.
# Upgrading relinks the binary but leaves a running server's process alone, so this is
# safe to run mid-session -- the new version applies to panes started afterwards.
if ! has herdr; then
  info "Installing Herdr..."
  case "$DOTFILES_OS" in
    macos) brew install herdr ;;
    linux) curl -fsSL https://herdr.dev/install.sh | sh || warn "Herdr install failed" ;;
    *)     warn "Unsupported OS for Herdr -- skipping" ;;
  esac
elif [ "$UPGRADE" = 1 ]; then
  info "Upgrading Herdr..."
  case "$DOTFILES_OS" in
    macos) brew upgrade herdr || ok "Herdr already at the latest release" ;;
    linux) curl -fsSL https://herdr.dev/install.sh | sh || warn "Herdr upgrade failed" ;;
  esac
else
  ok "Herdr already installed ($(herdr --version 2>/dev/null))"
fi

# --- Herdr agent skill ---
# The one global skill this repo installs. Everything else is per project (see
# docs/agent-skills-sources.md), but this skill is gated on HERDR_ENV=1 -- it is inert
# outside a Herdr pane, and Herdr is a machine-level tool rather than a project one, so
# scoping it to a project would just mean reinstalling it in every project.
# `-a '*'` writes the canonical copy to ~/.agents/skills/herdr and symlinks it into each
# detected agent. It reports a failure for agents with no global scope (Eve,
# PromptScript) and still exits 0; neither is installed here.
if ! has npx; then
  warn "npx not found -- skipping the Herdr agent skill"
elif [ "$UPGRADE" != 1 ] && [ -f "$HOME/.agents/skills/herdr/SKILL.md" ]; then
  ok "Herdr agent skill already installed"
else
  info "$VERB Herdr agent skill (global)..."
  npx skills@1.5.20 add herdrdev/herdr --skill herdr -a '*' -g -y \
    || warn "Herdr agent skill install failed"
fi

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
# Fresh install goes through npm; upgrades use Pi's built-in self-updater
# (`pi update`), which is faster and keeps Pi's own version bookkeeping intact.
if has "$PI_AGENT_BIN" || has "$PI_ALT_BIN"; then
  if [ "$UPGRADE" = 1 ]; then
    pi_bin="$(command -v "$PI_AGENT_BIN" || command -v "$PI_ALT_BIN")"
    info "Upgrading Pi coding agent (pi update)..."
    "$pi_bin" update
  else
    ok "Pi already installed"
  fi
elif has npm; then
  info "Installing Pi coding agent..."
  npm install -g "$PI_NPM_PACKAGE"
else
  warn "npm not found — skipping Pi"
fi

# Skill-installer CLIs are deliberately NOT installed here anymore -- skills come
# from the skills CLI per project, the Herdr skill above being the one global
# exception. See docs/removed-agent-clis.md for what used to live here and how to get
# each one back on demand.

if [ "$UPGRADE" = 1 ]; then
  ok "AI coding agents upgraded"
else
  ok "AI coding agents installation complete"
fi
