# Shared shell environment. Keep platform runtime managers in their platform rc.
export CLAUDE_CODE_NO_FLICKER=1

# Omarchy's agent-browser defaults to the everyday Chromium profile. The CLI
# clones it into a temporary user-data directory, so the daily browser remains
# usable concurrently. macOS keeps its existing isolated CDP default.
if command -v omarchy >/dev/null 2>&1 || [ -r /etc/omarchy-release ]; then
  export AGENT_BROWSER_PROFILE="${AGENT_BROWSER_PROFILE:-mfa}"
fi

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

if [ -d "$HOME/.opencode/bin" ]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

if [ -d "$HOME/.grok/bin" ]; then
  export PATH="$HOME/.grok/bin:$PATH"
fi
