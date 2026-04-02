#!/usr/bin/env bash
# Install AI coding agents: Claude Code, Codex, OpenCode, Pi
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing AI coding agents..."

# --- Claude Code ---
if ! has claude; then
  info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
else
  ok "Claude Code already installed"
fi

# --- OpenAI Codex CLI ---
if ! has codex; then
  info "Installing Codex CLI..."
  if has bun; then
    bun install -g @openai/codex
  elif has npm; then
    npm install -g @openai/codex
  else
    warn "Neither bun nor npm found — skipping Codex CLI"
  fi
else
  ok "Codex CLI already installed"
fi

# --- OpenCode ---
if ! has opencode; then
  info "Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash
else
  ok "OpenCode already installed"
fi

# --- Pi Coding Agent ---
if ! has pi; then
  info "Installing Pi coding agent..."
  if has npm; then
    npm install -g @mariozechner/pi-coding-agent
  else
    warn "npm not found — skipping Pi"
  fi
else
  ok "Pi already installed"
fi

# --- UI/UX Pro Max Skills ---
if ! has uipro; then
  info "Installing uipro-cli..."
  if has npm; then
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

ok "AI coding agents installation complete"
