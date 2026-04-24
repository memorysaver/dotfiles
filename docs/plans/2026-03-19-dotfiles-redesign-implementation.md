# Dotfiles Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reorganize dotfiles into a modular, idempotent, cross-platform system with justfile orchestration and cmux integration.

**Architecture:** Bootstrap script detects OS and installs foundation (brew/apt + git + zsh + just), then hands off to `just setup` which runs categorized install scripts and creates symlinks. All configs live under `config/`, agent configs under `agents/`, install scripts under `install/`, shared helpers in `lib/`.

**Tech Stack:** Bash, Just (task runner), direnv, zsh + oh-my-zsh + starship, cmux + tmux

---

### Task 1: Tag current state and clean up dead files

**Files:**
- Delete: `.spacemacs`
- Delete: `dev-container/` (empty directory)
- Delete: `.gitmodules` (empty file)
- Delete: `nvim/lua/plugins/example.lua` (disabled boilerplate)
- Delete: `nvim/lua/plugins/toggleterm-readme.md` (misplaced doc)
- Delete: `scripts/setup-mcp.sh` (redundant — symlink handles mcp config)
- Delete: `scripts/sync-codex-config.py` (unnecessary)
- Delete: `claude/claude-code-router/.env` (unused)
- Delete: `claude/claude-code-router/config.json` (replaced by env vars)
- Delete: `soundtrack/` (all 5 MP3s — cmux notifications replace audio)
- Delete: `claude/hooks/notification.py`
- Delete: `claude/hooks/pre_tool_use.py`
- Delete: `claude/hooks/session_start.py`
- Delete: `claude/hooks/stop.py`
- Delete: `claude/hooks/user_prompt_submit.py`
- Delete: `litellm/` (entire directory — replaced by env vars)
- Delete: `agent-deck/` (entire directory — cmux replaces)
- Delete: `.devcontainer/` (entire directory — deferred)
- Delete: `docs/simplification-report.md` (acted on, no longer needed)
- Delete: `docs/architecture-report.md` (stale)
- Delete: `docs/agentic-config-report.md` (stale)

**Step 1: Tag the pre-cleanup state**

```bash
git tag v0-pre-redesign -m "Pre-redesign snapshot: original dotfiles structure"
```

**Step 2: Remove dead files and directories**

```bash
git rm .spacemacs
git rm .gitmodules
git rm nvim/lua/plugins/example.lua
git rm nvim/lua/plugins/toggleterm-readme.md
git rm scripts/setup-mcp.sh
git rm scripts/sync-codex-config.py
git rm claude/claude-code-router/.env
git rm claude/claude-code-router/config.json
git rm -r soundtrack/
git rm claude/hooks/notification.py
git rm claude/hooks/pre_tool_use.py
git rm claude/hooks/session_start.py
git rm claude/hooks/stop.py
git rm claude/hooks/user_prompt_submit.py
git rm -r litellm/
git rm -r agent-deck/
git rm -r .devcontainer/
git rm docs/simplification-report.md
git rm docs/architecture-report.md
git rm docs/agentic-config-report.md
rmdir scripts/ 2>/dev/null || true
rmdir dev-container/ 2>/dev/null || true
rmdir claude/claude-code-router/ 2>/dev/null || true
```

**Step 3: Remove empty directories from git tracking**

```bash
# scripts/ and dev-container/ are untracked empties, just rmdir
rmdir scripts 2>/dev/null; rmdir dev-container 2>/dev/null
```

**Step 4: Commit**

```bash
git add -A
git commit -m "Clean up: remove dead files, stale configs, and audio hooks

Remove .spacemacs (unused, nvim is primary), .devcontainer (deferred),
soundtrack + Python hooks (cmux notifications replace), litellm +
claude-code-router (env vars replace), agent-deck (cmux replaces),
and stale docs/scripts.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: Create new folder structure and move configs

**Files:**
- Create: `lib/` directory
- Create: `install/` directory
- Create: `config/zsh/` directory
- Create: `config/tmux/` directory
- Create: `config/git/` directory
- Create: `config/starship/` directory (move from `starship/`)
- Create: `config/nvim/` (move from `nvim/`)
- Create: `config/lazygit/` (move from `lazygit/`)
- Create: `agents/claude/` (move from `claude/`)
- Create: `agents/codex/` (move from `openai-codex/`)
- Create: `agents/opencode/` (move from `opencode/`)
- Create: `agents/pi/` directory
- Create: `env/` directory

**Step 1: Create directory structure**

```bash
mkdir -p lib install config/zsh config/tmux config/git agents/pi env
```

**Step 2: Move existing configs into new structure**

```bash
# Shell configs
git mv .zshrc config/zsh/.zshrc
git mv .tmux.conf config/tmux/.tmux.conf

# Git configs
git mv git/.gitconfig config/git/.gitconfig
git mv git/.gitmessage config/git/.gitmessage
rmdir git

# Starship
git mv starship config/starship

# Nvim (entire directory)
git mv nvim config/nvim

# Lazygit
git mv lazygit config/lazygit

# Claude agent configs
git mv claude agents/claude

# Codex
git mv openai-codex agents/codex

# OpenCode
git mv opencode agents/opencode
```

**Step 3: Remove old install.sh (will be replaced by bootstrap.sh + justfile)**

```bash
git rm install.sh
```

**Step 4: Commit**

```bash
git add -A
git commit -m "Restructure: move configs into modular folder layout

config/ for shell/editor/tool configs, agents/ for AI tool configs,
lib/ for shared helpers, install/ for categorized install scripts,
env/ for direnv setup.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Create lib/helpers.sh — shared idempotent utilities

**Files:**
- Create: `lib/helpers.sh`

**Step 1: Write helpers.sh**

```bash
#!/usr/bin/env bash
# Shared helper functions for idempotent dotfiles installation
# Source this file: source "$(dirname "$0")/../lib/helpers.sh"

set -euo pipefail

# --- OS Detection ---
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

DOTFILES_OS="${DOTFILES_OS:-$(detect_os)}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# --- Logging ---
info()  { printf '  \033[34m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# --- Idempotent Helpers ---

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Install a package if the command is not already available
# Usage: ensure_installed <command_name> <brew_pkg> [apt_pkg]
# If apt_pkg is omitted, uses brew_pkg name
ensure_installed() {
  local cmd="$1" brew_pkg="$2" apt_pkg="${3:-$2}"
  if has "$cmd"; then
    ok "$cmd already installed"
    return 0
  fi
  info "Installing $cmd..."
  pkg_install "$brew_pkg" "$apt_pkg"
}

# Install a package via the OS package manager
# Usage: pkg_install <brew_pkg> [apt_pkg]
pkg_install() {
  local brew_pkg="$1" apt_pkg="${2:-$1}"
  case "$DOTFILES_OS" in
    macos) brew install "$brew_pkg" ;;
    linux) sudo apt-get install -y "$apt_pkg" ;;
    *)     fail "Unsupported OS: $DOTFILES_OS"; return 1 ;;
  esac
}

# Create a symlink only if it doesn't already point to the right target
# Usage: ensure_symlink <source> <destination>
ensure_symlink() {
  local src="$1" dest="$2"
  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "$(basename "$dest") already linked"
    return 0
  fi
  # Remove existing file/symlink/directory at dest
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  ln -s "$src" "$dest"
  ok "Linked $(basename "$dest") → $src"
}

# Ensure a directory exists
ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    return 0
  fi
  mkdir -p "$dir"
  ok "Created $dir"
}
```

**Step 2: Commit**

```bash
git add lib/helpers.sh
git commit -m "Add lib/helpers.sh: shared idempotent utilities

OS detection, logging, ensure_installed, ensure_symlink, pkg_install.
All functions check-before-act for safe re-runs.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Create install/core.sh

**Files:**
- Create: `install/core.sh`

**Step 1: Write core.sh**

```bash
#!/usr/bin/env bash
# Install core tools: zsh, oh-my-zsh, tmux, starship, nvim, lazygit, git, direnv
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing core tools..."

# --- Zsh ---
ensure_installed zsh zsh zsh

# --- Oh-My-Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Installing Oh-My-Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh-My-Zsh installed"
else
  ok "Oh-My-Zsh already installed"
fi

# --- Zsh plugins ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  info "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
  ok "zsh-autosuggestions already installed"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  info "Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
  ok "zsh-syntax-highlighting already installed"
fi

# --- Starship prompt ---
ensure_installed starship starship starship
# Linux fallback if not in apt:
if ! has starship && [ "$DOTFILES_OS" = "linux" ]; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# --- tmux ---
ensure_installed tmux tmux tmux

# --- Neovim ---
ensure_installed nvim neovim neovim

# --- Lazygit ---
if ! has lazygit; then
  info "Installing lazygit..."
  case "$DOTFILES_OS" in
    macos) brew install lazygit ;;
    linux)
      LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
      curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
      sudo tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
      rm /tmp/lazygit.tar.gz
      ;;
  esac
else
  ok "lazygit already installed"
fi

# --- Git ---
ensure_installed git git git

# --- Direnv ---
ensure_installed direnv direnv direnv

ok "Core tools installation complete"
```

**Step 2: Make executable**

```bash
chmod +x install/core.sh
```

**Step 3: Commit**

```bash
git add install/core.sh
git commit -m "Add install/core.sh: zsh, oh-my-zsh, tmux, starship, nvim, lazygit, direnv

Idempotent, cross-platform (brew/apt). Includes zsh plugins and
lazygit binary install fallback for Linux.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: Create install/runtimes.sh

**Files:**
- Create: `install/runtimes.sh`

**Step 1: Write runtimes.sh**

```bash
#!/usr/bin/env bash
# Install language runtimes: pyenv, uv, nvm, Node.js, Bun, Rust
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing language runtimes..."

# --- Pyenv ---
if ! has pyenv; then
  info "Installing pyenv..."
  curl https://pyenv.run | bash
else
  ok "pyenv already installed"
fi

# --- UV (Python package manager) ---
if ! has uv; then
  info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  ok "uv already installed"
fi

# --- NVM + Node.js ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -d "$NVM_DIR" ]; then
  info "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  ok "nvm already installed"
fi
# Source nvm for this script
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if ! has node; then
  info "Installing Node.js LTS..."
  nvm install --lts
else
  ok "Node.js already installed ($(node --version))"
fi

# --- Bun ---
if ! has bun; then
  info "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
else
  ok "Bun already installed"
fi

# --- Rust ---
if ! has rustc; then
  info "Installing Rust..."
  curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
else
  ok "Rust already installed"
fi

ok "Language runtimes installation complete"
```

**Step 2: Make executable and commit**

```bash
chmod +x install/runtimes.sh
git add install/runtimes.sh
git commit -m "Add install/runtimes.sh: pyenv, uv, nvm, Node.js, Bun, Rust

Idempotent installers for all language runtimes. Each checks
for existing installation before running.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: Create install/agents.sh

**Files:**
- Create: `install/agents.sh`

**Step 1: Write agents.sh**

```bash
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

ok "AI coding agents installation complete"
```

**Step 2: Make executable and commit**

```bash
chmod +x install/agents.sh
git add install/agents.sh
git commit -m "Add install/agents.sh: Claude Code, Codex, OpenCode, Pi

Idempotent installers for all AI coding agents. Uses curl
installers where available, falls back to npm/bun.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 7: Create install/tools.sh

**Files:**
- Create: `install/tools.sh`

**Step 1: Write tools.sh**

```bash
#!/usr/bin/env bash
# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing CLI tools..."

# --- GitHub CLI ---
if ! has gh; then
  info "Installing GitHub CLI..."
  case "$DOTFILES_OS" in
    macos) brew install gh ;;
    linux)
      (type -p wget >/dev/null || sudo apt-get install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
        && sudo apt-get update && sudo apt-get install -y gh
      ;;
  esac
else
  ok "gh already installed"
fi

# --- GitLab CLI ---
if ! has glab; then
  info "Installing GitLab CLI..."
  case "$DOTFILES_OS" in
    macos) brew install glab ;;
    linux)
      # Install via official script
      curl -fsSL https://raw.githubusercontent.com/profclems/glab/trunk/scripts/install.sh | sudo sh
      ;;
  esac
else
  ok "glab already installed"
fi

# --- jq ---
ensure_installed jq jq jq

# --- yq ---
if ! has yq; then
  info "Installing yq..."
  case "$DOTFILES_OS" in
    macos) brew install yq ;;
    linux)
      YQ_VERSION=$(curl -s "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
      curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
      sudo chmod +x /usr/local/bin/yq
      ;;
  esac
else
  ok "yq already installed"
fi

# --- Just (task runner) ---
if ! has just; then
  info "Installing just..."
  case "$DOTFILES_OS" in
    macos) brew install just ;;
    linux)
      curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
      ;;
  esac
else
  ok "just already installed"
fi

# --- Agent Browser (Vercel) ---
if ! has agent-browser; then
  info "Installing agent-browser..."
  if has npm; then
    npm install -g @anthropic-ai/agent-browser
  else
    warn "npm not found — skipping agent-browser"
  fi
else
  ok "agent-browser already installed"
fi

# --- Portless (Vercel) ---
if ! has portless; then
  info "Installing portless..."
  if has npm; then
    npm install -g @anthropic-ai/portless
  else
    warn "npm not found — skipping portless"
  fi
else
  ok "portless already installed"
fi

ok "CLI tools installation complete"
```

**Step 2: Make executable and commit**

```bash
chmod +x install/tools.sh
git add install/tools.sh
git commit -m "Add install/tools.sh: gh, glab, jq, yq, just, agent-browser, portless

Cross-platform installers for CLI tools. Uses brew on macOS,
apt/curl on Linux with binary fallbacks.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 8: Create install/infra.sh

**Files:**
- Create: `install/infra.sh`

**Step 1: Write infra.sh**

```bash
#!/usr/bin/env bash
# Install infrastructure tools: Terraform, Pulumi, SST (opt-in)
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing infrastructure tools..."

# --- Terraform ---
if ! has terraform; then
  info "Installing Terraform..."
  case "$DOTFILES_OS" in
    macos) brew install terraform ;;
    linux)
      wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update && sudo apt-get install -y terraform
      ;;
  esac
else
  ok "Terraform already installed"
fi

# --- Pulumi ---
if ! has pulumi; then
  info "Installing Pulumi..."
  curl -fsSL https://get.pulumi.com | sh
else
  ok "Pulumi already installed"
fi

# --- SST ---
if ! has sst; then
  info "Installing SST..."
  curl -fsSL https://sst.dev/install | bash
else
  ok "SST already installed"
fi

ok "Infrastructure tools installation complete"
```

**Step 2: Make executable and commit**

```bash
chmod +x install/infra.sh
git add install/infra.sh
git commit -m "Add install/infra.sh: Terraform, Pulumi, SST (opt-in)

Separate infra segment, not included in default 'just setup'.
Run with 'just infra' when needed.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 9: Write slim config/zsh/.zshrc and config/zsh/dev-envs.sh

**Files:**
- Modify: `config/zsh/.zshrc` (rewrite from bloated 514 lines to ~80 lines)
- Create: `config/zsh/dev-envs.sh`

**Step 1: Write the slim .zshrc**

```bash
# ~/.zshrc — managed by ~/.dotfiles
# Source: config/zsh/.zshrc

# --- Homebrew (must be first for macOS) ---
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# --- Editor ---
export EDITOR='nvim'

# --- PATH consolidation ---
# Language runtimes
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

export PATH="$HOME/.local/bin:$PATH"                          # uv, pipx
export PATH="$HOME/.cargo/bin:$PATH"                          # Rust
export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL" ]] && export PATH="$BUN_INSTALL/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# Tools
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

# --- Direnv ---
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# --- Aliases ---
alias ccusage="ccusage blocks --live"
alias ccyolo='claude --dangerously-skip-permissions'
alias ccyolow='claude --dangerously-skip-permissions -w'
alias ccyolotw='claude --dangerously-skip-permissions -w --tmux'

# --- AI Tools update ---
tool-update() {
  local failed=0
  echo "Updating AI tools..."
  curl -fsSL https://claude.ai/install.sh | bash || { echo "Claude Code failed"; failed=$((failed+1)); }
  curl -fsSL https://opencode.ai/install | bash || { echo "OpenCode failed"; failed=$((failed+1)); }
  has bun && bun install -g @openai/codex || { echo "Codex failed"; failed=$((failed+1)); }
  [ $failed -eq 0 ] && echo "All AI tools updated!" || echo "$failed tool(s) failed"
}

# --- Dev environments (tmux session helpers) ---
[ -f "$HOME/.dotfiles/config/zsh/dev-envs.sh" ] && source "$HOME/.dotfiles/config/zsh/dev-envs.sh"

# --- Bun completions ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# --- Starship prompt (must be last) ---
eval "$(starship init zsh)"
```

**Step 2: Write dev-envs.sh**

```bash
#!/usr/bin/env bash
# Tmux development environment helpers
# Sourced by .zshrc

# Modular tmux development environment
_create_dev_tmux_session() {
  local ai_tool_command="$1"
  local ai_tool_name="${2:-AI}"
  local session_name="${3:-$(basename "$(pwd)" | sed 's/[^a-zA-Z0-9]/_/g')}"

  tmux kill-session -t "$session_name" 2>/dev/null

  tmux new-session -d -s "$session_name" -c "$(pwd)"
  tmux split-window -h -c "$(pwd)"
  tmux select-pane -t "$session_name.0"
  tmux split-window -v -c "$(pwd)"

  sleep 0.1
  tmux resize-pane -t "$session_name.0" -x 55%
  tmux resize-pane -t "$session_name.0" -y 50%
  tmux resize-pane -t "$session_name.1" -y 50%
  tmux resize-pane -t "$session_name.2" -x 45%

  tmux send-keys -t "$session_name.0" 'lazygit' Enter
  tmux send-keys -t "$session_name.1" 'opencode' Enter
  tmux send-keys -t "$session_name.2" "$ai_tool_command" Enter

  tmux select-pane -t "$session_name.2"
  tmux attach-session -t "$session_name"
}

# Claude Code dev environment
ccdev() {
  _create_dev_tmux_session "claude --dangerously-skip-permissions" "Claude" "$1"
}

# OpenCode dev environment
opendev() {
  _create_dev_tmux_session "opencode" "OpenCode" "$1"
}

# Codex dev environment
codexdev() {
  if [[ -z "$1" ]]; then
    _create_dev_tmux_session "codex -m gpt-5.5 -c model_reasoning_effort=\"high\" -c model_reasoning_summary_format=experimental --search --dangerously-bypass-approvals-and-sandbox" "Codex-Enhanced"
  else
    _create_dev_tmux_session "codex --profile \"$1\" -c model_reasoning_effort=\"high\" -c model_reasoning_summary_format=experimental --search --dangerously-bypass-approvals-and-sandbox" "Codex-Enhanced" "$1"
  fi
}
```

**Step 3: Commit**

```bash
git add config/zsh/.zshrc config/zsh/dev-envs.sh
git commit -m "Rewrite .zshrc: slim down from 514 to ~80 lines

Remove oh-my-zsh boilerplate comments, LiteLLM proxy functions,
Claude Code Router, 1Password integration, Claude hook symlinks.
Consolidate PATH into single block. Extract tmux dev helpers to
dev-envs.sh. Keep: oh-my-zsh, starship, direnv, aliases, tool-update.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 10: Clean and merge config/tmux/.tmux.conf

**Files:**
- Modify: `config/tmux/.tmux.conf`

**Step 1: Rewrite .tmux.conf — merge agent-deck additions, remove duplicates, add passthrough**

The new `.tmux.conf` should:
- Remove the duplicate `default-terminal`, `escape-time`, `history-limit`, `mouse` settings from the agent-deck section
- Integrate the useful agent-deck scroll/copy bindings into the main config
- Add `set -g allow-passthrough on` for cmux notification escape sequences
- Use `tmux-256color` (from agent-deck) instead of `screen-256color`
- Remove SourceTree-related difftool/mergetool from gitconfig (done in Task 11)

Write the merged config preserving all non-duplicate settings, adding the passthrough line near the top after terminal settings.

**Step 2: Commit**

```bash
git add config/tmux/.tmux.conf
git commit -m "Merge tmux config: remove duplicates, add cmux passthrough

Integrate agent-deck scroll/copy bindings, remove 4 duplicate settings,
switch to tmux-256color, add allow-passthrough for cmux notifications.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 11: Clean config/git/.gitconfig

**Files:**
- Modify: `config/git/.gitconfig`

**Step 1: Remove stale entries**

Remove:
- `[difftool "sourcetree"]` section (lines 16-18)
- `[mergetool "sourcetree"]` section (lines 19-21)
- `[safe]` directory entry (lines 27-28) — machine-specific, shouldn't be in dotfiles

Keep everything else (user, commit template, push default, github user, core excludesfile, filter lfs).

**Step 2: Commit**

```bash
git add config/git/.gitconfig
git commit -m "Clean gitconfig: remove SourceTree and machine-specific entries

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 12: Create cmux-notify.sh hook

**Files:**
- Create: `agents/claude/hooks/cmux-notify.sh`
- Modify: `agents/claude/settings.json` (update hooks to use cmux-notify.sh)

**Step 1: Write cmux-notify.sh**

```bash
#!/bin/bash
# Claude Code hook: send notifications via cmux
# Falls back to no-op if not running in cmux

# Skip if cmux socket not available
[ -S /tmp/cmux.sock ] || exit 0

EVENT=$(cat)
EVENT_TYPE=$(echo "$EVENT" | jq -r '.hook_event_name // "unknown"')
TOOL=$(echo "$EVENT" | jq -r '.tool_name // ""')

case "$EVENT_TYPE" in
  "Stop")
    cmux notify --title "Claude Code" --body "Session complete"
    ;;
  "Notification")
    BODY=$(echo "$EVENT" | jq -r '.message // "Notification"')
    cmux notify --title "Claude Code" --subtitle "Notification" --body "$BODY"
    ;;
esac

exit 0
```

**Step 2: Update agents/claude/settings.json**

Replace the hooks section. Remove all `uv run --with pygame` Python hook references. Replace with the single cmux-notify.sh for Stop and Notification events only. Remove the SessionStart, UserPromptSubmit, and PreToolUse hooks entirely (cmux handles attention notifications natively).

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/cmux-notify.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/cmux-notify.sh"
          }
        ]
      }
    ]
  }
}
```

Keep all other settings.json fields unchanged (permissions, model, plugins, statusLine, etc.).

**Step 3: Make executable and commit**

```bash
chmod +x agents/claude/hooks/cmux-notify.sh
git add agents/claude/hooks/cmux-notify.sh agents/claude/settings.json
git commit -m "Add cmux-notify.sh: replace 5 Python hooks with single bash script

Uses cmux CLI for native notifications on Stop and Notification events.
Falls back to no-op when not running in cmux.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 13: Create env/.env.example and env/.envrc

**Files:**
- Create: `env/.env.example`
- Create: `env/.envrc`

**Step 1: Write .env.example**

```bash
# API Keys — copy to ~/.env and fill in your values
# This file is a template; ~/.env is gitignored

# Anthropic (Claude Code primary)
ANTHROPIC_API_KEY=

# Override API endpoint (for compatible proxies)
# ANTHROPIC_BASE_URL=https://api.anthropic.com

# Override model
# ANTHROPIC_MODEL=claude-opus-4-6

# OpenAI (Codex CLI)
OPENAI_API_KEY=

# OpenRouter (multi-model access)
OPENROUTER_API_KEY=

# Groq (fast inference)
GROQ_API_KEY=

# GitHub (for gh CLI — or use `gh auth login`)
# GITHUB_TOKEN=

# GitLab (for glab CLI — or use `glab auth login`)
# GITLAB_TOKEN=
```

**Step 2: Write .envrc**

```bash
# direnv configuration — symlinked to ~/.envrc
# Loads API keys and config from ~/.env

if [ -f "$HOME/.env" ]; then
  dotenv "$HOME/.env"
fi
```

**Step 3: Commit**

```bash
git add env/.env.example env/.envrc
git commit -m "Add env config: .env.example template and .envrc for direnv

Replaces 1Password CLI, LiteLLM proxy, and Claude Code Router
with simple .env + direnv approach.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 14: Create justfile

**Files:**
- Create: `justfile`

**Step 1: Write justfile**

```just
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

  # Direnv (global)
  ensure_symlink "{{dotfiles}}/env/.envrc" "$HOME/.envrc"

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
    "$HOME/.envrc"
  )
  for link in "${links[@]}"; do
    [ -L "$link" ] && rm "$link" && ok "Removed $link"
  done
```

**Step 2: Commit**

```bash
git add justfile
git commit -m "Add justfile: orchestrate setup, install segments, and symlinks

Recipes: setup, core, runtimes, agents, tools, infra (opt-in), link, unlink.
All idempotent. Uses lib/helpers.sh for cross-platform support.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 15: Create bootstrap.sh

**Files:**
- Create: `bootstrap.sh`

**Step 1: Write bootstrap.sh**

```bash
#!/usr/bin/env bash
# Bootstrap dotfiles on a fresh machine
# Usage: curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/bootstrap.sh | bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
REPO="https://github.com/memorysaver/dotfiles.git"

echo "=== Dotfiles Bootstrap ==="

# --- Detect OS ---
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac
echo "Detected OS: $OS"

# --- Install foundation ---
if [ "$OS" = "macos" ]; then
  # Xcode CLI tools
  if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode CLI tools..."
    xcode-select --install
    echo "Press Enter after Xcode CLI tools installation completes..."
    read -r
  fi

  # Homebrew
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
else
  # Linux: ensure essentials
  echo "Updating package lists..."
  sudo apt-get update -y
  sudo apt-get install -y git curl wget build-essential
fi

# --- Git ---
if ! command -v git &>/dev/null; then
  echo "Installing git..."
  if [ "$OS" = "macos" ]; then
    brew install git
  else
    sudo apt-get install -y git
  fi
fi

# --- Clone dotfiles ---
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Cloning dotfiles..."
  git clone "$REPO" "$DOTFILES_DIR"
else
  echo "Dotfiles already at $DOTFILES_DIR"
fi

# --- Zsh (needed before oh-my-zsh) ---
if ! command -v zsh &>/dev/null; then
  echo "Installing zsh..."
  if [ "$OS" = "macos" ]; then
    brew install zsh
  else
    sudo apt-get install -y zsh
  fi
fi

# Set zsh as default shell if it isn't already
if [ "$(basename "$SHELL")" != "zsh" ]; then
  echo "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
fi

# --- Just (task runner) ---
if ! command -v just &>/dev/null; then
  echo "Installing just..."
  if [ "$OS" = "macos" ]; then
    brew install just
  else
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
  fi
fi

# --- Hand off to just ---
echo ""
echo "=== Running just setup ==="
cd "$DOTFILES_DIR"
just setup

echo ""
echo "=== Bootstrap complete! ==="
echo "Restart your shell or run: exec zsh"
```

**Step 2: Make executable and commit**

```bash
chmod +x bootstrap.sh
git add bootstrap.sh
git commit -m "Add bootstrap.sh: one-command setup for fresh machines

Detects OS, installs foundation (brew/apt, git, zsh, just),
clones dotfiles, and runs 'just setup'. Curl-able entry point.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 16: Update .gitignore

**Files:**
- Modify: `.gitignore`

**Step 1: Replace Python template with dotfiles-appropriate .gitignore**

```
# OS
.DS_Store

# Environment (secrets)
.env
*.local

# Claude Code
.claude/debug/

# Python bytecode
__pycache__/
*.pyc

# Editor
*.swp
*.swo
*~

# Node
node_modules/
```

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "Replace Python template .gitignore with dotfiles-appropriate one

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 17: Update README.md

**Files:**
- Modify: `README.md`

**Step 1: Rewrite README to reflect new structure**

Write a concise README covering:
- One-line install command (`curl | bash`)
- What's included (core, runtimes, agents, tools, infra)
- Folder structure overview
- `just` recipes reference
- Environment variables setup (`.env.example` → `~/.env`)
- Key tools: cmux + tmux, starship, nvim, lazygit, Claude Code

Remove all the old prerequisite manual install instructions — that's what the scripts do now.

**Step 2: Commit**

```bash
git add README.md
git commit -m "Rewrite README for new modular dotfiles structure

One-command install, just recipes, folder structure overview.
Replaces manual prerequisite instructions.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 18: Verify the full setup

**Step 1: Run `just link` to verify symlink creation**

```bash
cd ~/.dotfiles && just link
```

Expected: All symlinks created without errors.

**Step 2: Verify file structure matches design**

```bash
find ~/.dotfiles -maxdepth 3 -not -path '*/.git/*' | sort
```

Expected: Matches the folder structure from the design doc.

**Step 3: Verify .zshrc can be sourced without errors**

```bash
zsh -c "source ~/.dotfiles/config/zsh/.zshrc && echo 'OK'"
```

**Step 4: Verify each install script is syntactically valid**

```bash
for f in install/*.sh; do bash -n "$f" && echo "$f: OK"; done
bash -n bootstrap.sh && echo "bootstrap.sh: OK"
bash -n lib/helpers.sh && echo "lib/helpers.sh: OK"
```

**Step 5: Verify justfile parses correctly**

```bash
just --list
```

Expected: Shows all recipes (setup, core, runtimes, agents, tools, infra, link, unlink).

---

Plan complete and saved to `docs/plans/2026-03-19-dotfiles-redesign-implementation.md`. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** — Open new session with executing-plans, batch execution with checkpoints

Which approach?
