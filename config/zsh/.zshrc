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
alias agyolo='agy --dangerously-skip-permissions'
alias codexyolo='codex --yolo'
alias ccyolow='claude --dangerously-skip-permissions --rc -w'
alias ccyolotw='claude --dangerously-skip-permissions --rc -w --tmux'
if [[ "$(uname -s)" == Darwin ]]; then
  alias obsidian='open -a Obsidian'
fi
alias ccauto='claude --permission-mode auto --rc'
alias ccautow='claude --permission-mode auto --rc -w'
alias ccautotw='claude --permission-mode auto --rc -w --tmux'

# --- Herdr cockpit ---
[[ -f "$HOME/.dotfiles/config/zsh/cockpit.zsh" ]] && source "$HOME/.dotfiles/config/zsh/cockpit.zsh"

# --- Chrome CDP (browser automation) ---
_chrome_cdp_ready() {
  local port="${1:-9222}"
  curl -fsS "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

_chrome_cdp_clear_stale_locks() {
  local dir="$1"
  local lock="$dir/SingletonLock"

  [[ -e "$lock" ]] || return 0

  local target pid
  target="$(readlink "$lock" 2>/dev/null || true)"
  pid="${target##*-}"

  if [[ "$pid" == <-> ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Chrome profile is already locked by PID $pid: $dir" >&2
    return 1
  fi

  rm -f "$dir/SingletonLock" "$dir/SingletonSocket" "$dir/SingletonCookie"
}

chrome-cdp() {
  local name="${1:-default}"
  local port="${2:-9222}"
  local dir="$HOME/.chrome-cdp/$name"

  mkdir -p "$dir"

  if _chrome_cdp_ready "$port"; then
    echo "Chrome '$name' already listening on port $port"
    return 0
  fi

  if lsof -nP -iTCP:"$port" -sTCP:LISTEN &>/dev/null; then
    echo "Port $port is in use, but it is not a reachable Chrome CDP endpoint"
    return 1
  fi

  _chrome_cdp_clear_stale_locks "$dir" || return 1

  if [[ "$(uname -s)" == Darwin ]]; then
    open -na "Google Chrome" --args \
      --remote-debugging-port="$port" \
      --remote-allow-origins="*" \
      --user-data-dir="$dir"
  else
    local browser
    browser="$(command -v chromium || command -v google-chrome || true)"
    [[ -n "$browser" ]] || { echo "Chromium/Chrome not found" >&2; return 1; }
    setsid "$browser" \
      --remote-debugging-port="$port" \
      --remote-allow-origins="*" \
      --user-data-dir="$dir" >/dev/null 2>&1 &
  fi

  local i
  for i in {1..20}; do
    if _chrome_cdp_ready "$port"; then
      echo "Chrome '$name' on port $port"
      return 0
    fi
    sleep 0.25
  done

  echo "Chrome '$name' was launched, but CDP did not become reachable on port $port" >&2
  return 1
}

ab-connect() {
  local name="${1:-default}"
  local port="${2:-9222}"

  chrome-cdp "$name" "$port" || return 1
  agent-browser --session "$name" connect "$port"
}

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

# Looplia Run
export PATH="$HOME/.looplia/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
