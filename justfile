# Dotfiles task runner
# Usage: just <recipe>
# Run `just --list` to see all available recipes

set shell := ["bash", "-euo", "pipefail", "-c"]
dotfiles := env("HOME") / ".dotfiles"

# Run full setup (idempotent — safe to re-run)
setup: core runtimes agents tools link
  @echo ""
  @echo "Setup complete! Restart your shell or run: source ~/.zshrc"

# Install core tools: zsh, oh-my-zsh, tmux, starship, nvim, lazygit, direnv
core:
  @bash {{dotfiles}}/install/core.sh

# Install language runtimes: pyenv, uv, nvm, Node.js, Bun, Rust
runtimes:
  @bash {{dotfiles}}/install/runtimes.sh

# Install AI coding agents: Claude Code, Codex, OpenCode, Pi
agents:
  @bash {{dotfiles}}/install/agents.sh

# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless
tools:
  @bash {{dotfiles}}/install/tools.sh

# Install infrastructure tools: Terraform, Pulumi, SST (opt-in)
infra:
  @bash {{dotfiles}}/install/infra.sh

# Create all config symlinks (idempotent)
link:
  #!/usr/bin/env bash
  source {{dotfiles}}/lib/helpers.sh
  info "Linking configuration files..."

  # Shell
  ensure_symlink "{{dotfiles}}/config/zsh/.zshrc" "$HOME/.zshrc"
  ensure_symlink "{{dotfiles}}/config/tmux/.tmux.conf" "$HOME/.tmux.conf"

  # Git
  ensure_symlink "{{dotfiles}}/config/git/.gitconfig" "$HOME/.gitconfig"
  ensure_symlink "{{dotfiles}}/config/git/.gitmessage" "$HOME/.gitmessage"

  # Editors & tools
  ensure_symlink "{{dotfiles}}/config/nvim" "$HOME/.config/nvim"
  ensure_symlink "{{dotfiles}}/config/starship/starship.toml" "$HOME/.config/starship.toml"

  # Lazygit (OS-dependent path)
  if [ "$DOTFILES_OS" = "macos" ]; then
    ensure_symlink "{{dotfiles}}/config/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
  else
    ensure_symlink "{{dotfiles}}/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
  fi

  # SketchyBar (macOS only)
  if [ "$DOTFILES_OS" = "macos" ]; then
    ensure_symlink "{{dotfiles}}/config/sketchybar" "$HOME/.config/sketchybar"
  fi

  # Claude Code
  ensure_dir "$HOME/.claude"
  ensure_dir "$HOME/.claude/hooks"
  ensure_dir "$HOME/.claude/commands"
  ensure_symlink "{{dotfiles}}/agents/claude/settings.json" "$HOME/.claude/settings.json"
  ensure_symlink "{{dotfiles}}/agents/claude/mcp-servers.json" "$HOME/.claude/mcp-servers.json"
  ensure_symlink "{{dotfiles}}/agents/claude/statusline.sh" "$HOME/.claude/statusline.sh"
  chmod +x "{{dotfiles}}/agents/claude/statusline.sh"
  # Symlink all hooks
  for hook in {{dotfiles}}/agents/claude/hooks/*; do
    [ -f "$hook" ] && ensure_symlink "$hook" "$HOME/.claude/hooks/$(basename "$hook")"
  done
  # Symlink all commands
  for cmd in {{dotfiles}}/agents/claude/commands/*; do
    [ -f "$cmd" ] && ensure_symlink "$cmd" "$HOME/.claude/commands/$(basename "$cmd")"
  done
  # Symlink output-styles directory
  ensure_symlink "{{dotfiles}}/agents/claude/output-styles" "$HOME/.claude/output-styles"

  # Codex CLI
  ensure_dir "$HOME/.codex"
  ensure_symlink "{{dotfiles}}/agents/codex/config.toml" "$HOME/.codex/config.toml"

  # OpenCode
  ensure_dir "$HOME/.config/opencode"
  ensure_symlink "{{dotfiles}}/agents/opencode/opencode.json" "$HOME/.config/opencode/opencode.json"
  ensure_symlink "{{dotfiles}}/agents/opencode/oh-my-opencode.json" "$HOME/.config/opencode/oh-my-opencode.json"

  ok "All symlinks created"

# Unlink all symlinks (for clean removal)
unlink:
  #!/usr/bin/env bash
  source {{dotfiles}}/lib/helpers.sh
  links=(
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
    "$HOME/.gitmessage"
    "$HOME/.config/nvim"
    "$HOME/.config/starship.toml"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/mcp-servers.json"
    "$HOME/.claude/statusline.sh"
    "$HOME/.claude/output-styles"
    "$HOME/.codex/config.toml"
    "$HOME/.config/opencode/opencode.json"
    "$HOME/.config/opencode/oh-my-opencode.json"
  )
  # Lazygit (OS-dependent path)
  if [ "$(uname)" = "Darwin" ]; then
    links+=("$HOME/Library/Application Support/lazygit/config.yml")
  else
    links+=("$HOME/.config/lazygit/config.yml")
  fi
  # SketchyBar (macOS only)
  if [ "$(uname)" = "Darwin" ]; then
    links+=("$HOME/.config/sketchybar")
  fi
  # Claude hooks
  for hook in "$HOME/.claude/hooks/"*; do
    [ -L "$hook" ] && links+=("$hook")
  done
  # Claude commands
  for cmd in "$HOME/.claude/commands/"*; do
    [ -L "$cmd" ] && links+=("$cmd")
  done
  for link in "${links[@]}"; do
    [ -L "$link" ] && rm "$link" && ok "Removed $link"
  done
