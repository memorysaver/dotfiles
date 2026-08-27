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

# The CLI lives in pi-coding-agent, not pi. @mariozechner/pi kept the name but
# ships only the pi-pods binary now, and the rename warning it prints points at
# @earendil-works/pi-agent-core, which is the library half and has no bin at all
# -- following either one leaves the machine with no `pi`. Needs node >=22.19.0;
# the legacy-node20 dist-tag is the fallback for anything older.
PI_NPM_PACKAGE="${PI_NPM_PACKAGE:-@earendil-works/pi-coding-agent}"
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
  case "$DOTFILES_PLATFORM" in
    macos) brew install herdr ;;
    omarchy|arch|debian) curl -fsSL https://herdr.dev/install.sh | sh || warn "Herdr install failed" ;;
    *)     warn "Unsupported OS for Herdr -- skipping" ;;
  esac
elif [ "$UPGRADE" = 1 ]; then
  info "Upgrading Herdr..."
  case "$DOTFILES_PLATFORM" in
    macos) brew upgrade herdr || ok "Herdr already at the latest release" ;;
    omarchy|arch|debian) curl -fsSL https://herdr.dev/install.sh | sh || warn "Herdr upgrade failed" ;;
  esac
else
  ok "Herdr already installed ($(herdr --version 2>/dev/null))"
fi

# --- Global agent skills ---
# The only skills installed globally. Everything else is per project -- see
# docs/agent-skills-sources.md for the policy and the bar an entry has to clear:
# inert until deliberately activated, so it cannot misfire on an unrelated task, and
# about the machine rather than about one project.
#   herdr          requires HERDR_ENV=1 and stops when it is unset
#   i-have-adhd    disable-model-invocation: true -- only fires on /i-have-adhd
#   agent-browser  deliberate override, added 2026-08-04: it does NOT meet the inert
#                  condition. Broad model-invocable description that ends "Prefer
#                  agent-browser over any built-in browser automation or web tools",
#                  so it is live in every session and outranks the harness's own
#                  browser tooling. Kept global on purpose because the CLI it drives
#                  is installed globally by tools.sh. To undo:
#                  npx skills@1.5.20 remove agent-browser -g -a '*' -y
# `-a '*'` writes the canonical copy to ~/.agents/skills/<name> and symlinks it into
# each detected agent. It reports a failure for agents with no global scope (Eve,
# PromptScript) and still exits 0; neither is installed here.
GLOBAL_SKILLS="herdrdev/herdr:herdr ayghri/i-have-adhd:i-have-adhd vercel-labs/agent-browser:agent-browser"

if ! has npx; then
  warn "npx not found -- skipping global agent skills"
else
  for entry in $GLOBAL_SKILLS; do
    repo="${entry%%:*}" skill="${entry##*:}"
    if [ "$UPGRADE" != 1 ] && [ -f "$HOME/.agents/skills/$skill/SKILL.md" ]; then
      ok "Skill '$skill' already installed"
    else
      info "$VERB skill '$skill' (global)..."
      npx --yes skills@1.5.20 add "$repo" --skill "$skill" -a '*' -g -y \
        || warn "Skill '$skill' install failed"
    fi
  done
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

# --- Grok Build (xAI) --- (curl installer is idempotent and upgrades in place)
# Official released-binary path from xai-org/grok-build's README. That repo is the
# Rust source, for people building it themselves; we take the prebuilt binary, which
# lands in ~/.grok/downloads/ with ~/.grok/bin/grok symlinked at it.
#
# Unlike the Codex installer above, this one has no equivalent of
# CODEX_NON_INTERACTIVE: it always rewrites its own `# >>> grok installer >>>` block
# in the profile for $SHELL, replacing any existing copy. Only GROK_BIN_DIR,
# GROK_CHANNEL, GROK_PROXY_URL and GROK_DEPLOYMENT_KEY are configurable. Since
# ~/.zshrc is symlinked to config/zsh/.zshrc, every run writes into this repo. The
# block committed there is byte-identical to what the installer currently emits, so
# this is a no-op today -- but if xAI edits that template, it lands as an
# unexplained diff in `git status`. Same in-place-rewrite hazard as the herdr and
# agent configs; see the README's "Agent Configs Are Machine-Local".
if should_setup grok; then
  info "$VERB Grok Build..."
  curl -fsSL https://x.ai/cli/install.sh | bash || warn "grok install failed"
else
  ok "Grok Build already installed ($(grok --version 2>/dev/null))"
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
