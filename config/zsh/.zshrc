# ~/.zshrc — managed by ~/.dotfiles
# Source: config/zsh/.zshrc

# --- Platform path ---
if [[ "$(uname -s)" == Darwin ]]; then
  export BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
  export PATH="$BREW_PREFIX/bin:/usr/local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
fi

# --- Oh-My-Zsh ---
export ZSH="$HOME/.oh-my-zsh"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
# opencli completion
[[ -d "$HOME/.zsh/completions" ]] && fpath=("$HOME/.zsh/completions" $fpath)
source "$ZSH/oh-my-zsh.sh"

# --- Portable personal configuration ---
for fragment in env aliases functions; do
  [[ -r "$HOME/.dotfiles/config/shell/common/${fragment}.sh" ]] && \
    source "$HOME/.dotfiles/config/shell/common/${fragment}.sh"
done
unset fragment

# --- Editor ---
export EDITOR='nvim'

# --- PATH consolidation ---
# Language runtimes
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init - --no-rehash)"
  eval "$(pyenv virtualenv-init - --no-rehash)"
fi

export BUN_INSTALL="$HOME/.bun"
[[ -d "$BUN_INSTALL" ]] && export PATH="$BUN_INSTALL/bin:$PATH"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# --- Direnv ---
if command -v direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# --- Platform aliases ---
if [[ "$(uname -s)" == Darwin ]]; then
  alias obsidian='open -a Obsidian'
fi

# --- Herdr cockpit ---
[[ -f "$HOME/.dotfiles/config/zsh/cockpit.zsh" ]] && source "$HOME/.dotfiles/config/zsh/cockpit.zsh"

# --- AI Tools update ---
tool-update() {
  local failed=0
  echo "Updating AI tools..."
  if command -v omarchy &>/dev/null || [[ -r /etc/omarchy-release ]]; then
    omarchy-mise-install claude || { echo "Claude Code failed"; failed=$((failed+1)); }
    omarchy-mise-install codex || { echo "Codex failed"; failed=$((failed+1)); }
    omarchy-mise-install opencode || { echo "OpenCode failed"; failed=$((failed+1)); }
  else
    curl -fsSL https://claude.ai/install.sh | bash || { echo "Claude Code failed"; failed=$((failed+1)); }
    CODEX_NON_INTERACTIVE=1 curl -fsSL https://chatgpt.com/codex/install.sh | sh \
      || { echo "Codex failed"; failed=$((failed+1)); }
    curl -fsSL https://opencode.ai/install | bash || { echo "OpenCode failed"; failed=$((failed+1)); }
  fi
  [ $failed -eq 0 ] && echo "All AI tools updated!" || echo "$failed tool(s) failed"
}

# --- Dev environments (tmux session helpers) ---
[ -f "$HOME/.dotfiles/config/zsh/dev-envs.sh" ] && source "$HOME/.dotfiles/config/zsh/dev-envs.sh"

# --- Bun completions ---
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# --- Starship prompt (must be last) ---
eval "$(starship init zsh)"

# Looplia Run
export PATH="$HOME/.looplia/bin:$PATH"

# >>> grok installer >>>
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
