# ~/.zshrc — managed by ~/.dotfiles
# Source: config/zsh/.zshrc

# --- Homebrew (must be first for macOS) ---
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
# opencli completion
fpath=(/Users/memorysaver/.zsh/completions $fpath)
source "$ZSH/oh-my-zsh.sh"

# --- Editor ---
export EDITOR='nvim'

# --- Claude Code ---
export CLAUDE_CODE_NO_FLICKER=1

# --- PATH consolidation ---
# Language runtimes
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init - --no-rehash)"
  eval "$(pyenv virtualenv-init - --no-rehash)"
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
alias ccyolo='claude --dangerously-skip-permissions --rc'
alias ccyolow='claude --dangerously-skip-permissions --rc -w'
alias ccyolotw='claude --dangerously-skip-permissions --rc -w --tmux'
alias obsidian='Obsidian'
alias ccauto='claude --permission-mode auto --rc'
alias ccautow='claude --permission-mode auto --rc -w'
alias ccautotw='claude --permission-mode auto --rc -w --tmux'

# --- AI Tools update ---
tool-update() {
  local failed=0
  echo "Updating AI tools..."
  curl -fsSL https://claude.ai/install.sh | bash || { echo "Claude Code failed"; failed=$((failed+1)); }
  curl -fsSL https://opencode.ai/install | bash || { echo "OpenCode failed"; failed=$((failed+1)); }
  if command -v bun &>/dev/null; then
    bun install -g @openai/codex || { echo "Codex failed"; failed=$((failed+1)); }
  else
    echo "Bun not found — skipping Codex update"
  fi
  [ $failed -eq 0 ] && echo "All AI tools updated!" || echo "$failed tool(s) failed"
}

# --- Dev environments (tmux session helpers) ---
[ -f "$HOME/.dotfiles/config/zsh/dev-envs.sh" ] && source "$HOME/.dotfiles/config/zsh/dev-envs.sh"

# --- Bun completions ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# --- Starship prompt (must be last) ---
eval "$(starship init zsh)"
export PATH="$HOME/.looplia/bin:$PATH"
