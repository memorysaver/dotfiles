# Shared shell environment. Keep platform runtime managers in their platform rc.
export CLAUDE_CODE_NO_FLICKER=1

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

if [ -d "$HOME/.opencode/bin" ]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

if [ -d "$HOME/.grok/bin" ]; then
  export PATH="$HOME/.grok/bin:$PATH"
fi
