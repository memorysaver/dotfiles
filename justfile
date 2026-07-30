# Dotfiles task runner
# Usage: just <recipe>
# Run `just --list` to see all available recipes

set shell := ["bash", "-euo", "pipefail", "-c"]
dotfiles := env("HOME") / ".dotfiles"

# Run full setup (idempotent — safe to re-run)
setup: core runtimes agents tools link seed-agents
  @echo ""
  @echo "Setup complete! Restart your shell or run: source ~/.zshrc"

# Install core tools: zsh, oh-my-zsh, tmux, starship, nvim, lazygit, direnv
core:
  @bash {{dotfiles}}/install/core.sh

# Install language runtimes: pyenv, uv, nvm, Node.js, Bun, Rust
runtimes:
  @bash {{dotfiles}}/install/runtimes.sh

# Install AI coding agents: Claude Code, Codex, OpenCode, Pi, Antigravity CLI (agy)
agents:
  @bash {{dotfiles}}/install/agents.sh

# Upgrade all AI coding agents to their latest release
update-agents:
  @bash {{dotfiles}}/install/agents.sh --upgrade

# Validate shared skills for Claude Code, Codex, Pi, and Antigravity CLI portability
validate-skills:
  @bash {{dotfiles}}/tools/validate-agent-skills.sh

# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless
tools:
  @bash {{dotfiles}}/install/tools.sh

# Install infrastructure tools: Terraform, Pulumi, SST (opt-in)
infra:
  @bash {{dotfiles}}/install/infra.sh

# Clone/pull personal workspace repos defined in install/repos.txt
repos:
  @bash {{dotfiles}}/install/repos.sh

# Create all config symlinks (idempotent)
link:
  #!/usr/bin/env bash
  source {{dotfiles}}/lib/helpers.sh
  info "Linking configuration files..."

  # Shell
  ensure_symlink "{{dotfiles}}/config/zsh/.zshenv" "$HOME/.zshenv"
  ensure_symlink "{{dotfiles}}/config/zsh/.zshrc" "$HOME/.zshrc"
  ensure_symlink "{{dotfiles}}/config/tmux/.tmux.conf" "$HOME/.tmux.conf"

  # Git
  ensure_symlink "{{dotfiles}}/config/git/.gitconfig" "$HOME/.gitconfig"
  ensure_symlink "{{dotfiles}}/config/git/.gitmessage" "$HOME/.gitmessage"

  # Editors & tools
  ensure_symlink "{{dotfiles}}/config/nvim" "$HOME/.config/nvim"
  ensure_symlink "{{dotfiles}}/config/starship/starship.toml" "$HOME/.config/starship.toml"

  # Herdr (link the file only -- the dir also holds sockets, logs, session state)
  ensure_dir "$HOME/.config/herdr"
  ensure_symlink "{{dotfiles}}/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"

  # Lazygit (OS-dependent path)
  if [ "$DOTFILES_OS" = "macos" ]; then
    ensure_symlink "{{dotfiles}}/config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
  else
    ensure_symlink "{{dotfiles}}/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  fi

  # Coding-agent configs are NOT symlinked. Claude Code, Codex, Pi and OpenCode
  # all rewrite their own config in place, and their formats change faster than a
  # shared repo can track. Each machine owns its own copy under ~/. What lives in
  # agents/*/ is a reference template -- run `just seed-agents` to copy it onto a
  # fresh machine, then let the machine diverge. Skills likewise install per
  # project via the skills CLI; see docs/agent-skills-sources.md.

  ok "All symlinks created"

# Copy agent config templates to a fresh machine (never overwrites an existing file)
seed-agents:
  #!/usr/bin/env bash
  source {{dotfiles}}/lib/helpers.sh
  info "Seeding agent configs (existing files are left untouched)..."

  seed() {
    local src="$1" dest="$2"
    if [ -e "$dest" ]; then
      warn "exists, skipped: $dest"
    else
      ensure_dir "$(dirname "$dest")"
      cp -R "$src" "$dest"
      ok "seeded $dest"
    fi
  }

  # Claude Code
  ensure_dir "$HOME/.claude/hooks"
  seed "{{dotfiles}}/agents/claude/settings.json"  "$HOME/.claude/settings.json"
  seed "{{dotfiles}}/agents/claude/statusline.sh"  "$HOME/.claude/statusline.sh"
  seed "{{dotfiles}}/agents/claude/output-styles"  "$HOME/.claude/output-styles"
  for hook in {{dotfiles}}/agents/claude/hooks/*; do
    [ -f "$hook" ] && seed "$hook" "$HOME/.claude/hooks/$(basename "$hook")"
  done
  [ -f "$HOME/.claude/statusline.sh" ] && chmod +x "$HOME/.claude/statusline.sh"

  # Codex CLI
  seed "{{dotfiles}}/agents/codex/config.toml" "$HOME/.codex/config.toml"
  seed "{{dotfiles}}/agents/codex/AGENTS.md"   "$HOME/.codex/AGENTS.md"

  # Pi
  seed "{{dotfiles}}/agents/pi/settings.json" "$HOME/.pi/agent/settings.json"

  # OpenCode
  seed "{{dotfiles}}/agents/opencode/opencode.json"       "$HOME/.config/opencode/opencode.json"
  seed "{{dotfiles}}/agents/opencode/oh-my-opencode.json" "$HOME/.config/opencode/oh-my-opencode.json"

  ok "Agent configs seeded -- they are yours to edit now, this repo will not touch them again"

# Unlink all symlinks (for clean removal)
unlink:
  #!/usr/bin/env bash
  source {{dotfiles}}/lib/helpers.sh
  links=(
    "$HOME/.zshenv"
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
    "$HOME/.gitmessage"
    "$HOME/.config/nvim"
    "$HOME/.config/starship.toml"
    "$HOME/.config/herdr/config.toml"
  )
  # Lazygit (OS-dependent path)
  if [ "$(uname)" = "Darwin" ]; then
    links+=("$HOME/Library/Application Support/lazygit/config.yml")
  else
    links+=("$HOME/.config/lazygit/config.yml")
  fi
  # Agent configs and skills are not symlinked, so there is nothing to unlink for
  # them. Whatever sits under ~/.claude, ~/.codex, ~/.pi and ~/.config/opencode
  # belongs to this machine and is left alone.
  for link in "${links[@]}"; do
    [ -L "$link" ] && rm "$link" && ok "Removed $link"
  done

# Report any symlink still pointing into this repo from an agent config directory
check-agent-links:
  @bash {{dotfiles}}/tools/agent-links.sh check

# Turn agent config symlinks into real machine-local files (run once per old machine)
adopt-agents:
  @bash {{dotfiles}}/tools/agent-links.sh adopt
