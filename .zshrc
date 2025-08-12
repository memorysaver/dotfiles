# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# Caution: this setting can cause issues with multiline prompts (zsh 5.7.1 and newer seem to work)
# See https://github.com/ohmyzsh/ohmyzsh/issues/5765
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git poetry)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
export EDITOR='nvim'

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Claude Code aliases
alias ccusage="ccusage blocks --live"
# Claude Code + LiteLLM with auto-start check
cclitellm() {
    local model="${1:-openrouter/qwen/qwen3-coder}"
    
    # Ensure LiteLLM is running
    _ensure_litellm_running || return 1
    
    # Launch Claude Code with LiteLLM configuration
    eval "$(_create_claude_litellm_command "$model")"
}

# Shared function to ensure LiteLLM proxy is running
_ensure_litellm_running() {
    # Check if LiteLLM proxy is running on port 4000
    if ! curl -s http://localhost:4000/health > /dev/null 2>&1; then
        echo "🔄 LiteLLM proxy not running, starting it..."
        litellm-start
        
        # If litellm-start fails, exit
        if [ $? -ne 0 ]; then
            echo "❌ Failed to start LiteLLM proxy"
            return 1
        fi
        
        # Wait for LiteLLM to be ready
        echo "⏳ Waiting for LiteLLM proxy to start..."
        local attempts=0
        while ! curl -s http://localhost:4000/health > /dev/null 2>&1; do
            sleep 2
            attempts=$((attempts + 1))
            if [ $attempts -gt 15 ]; then
                echo "❌ LiteLLM proxy failed to start within 30 seconds"
                return 1
            fi
        done
        echo "✅ LiteLLM proxy is ready!"
    else
        echo "✅ LiteLLM proxy already running"
    fi
    return 0
}

# Create Claude Code command with LiteLLM configuration
_create_claude_litellm_command() {
    local model="${1:-openrouter/qwen/qwen3-coder}"
    echo "ANTHROPIC_AUTH_TOKEN=sk-1234 ANTHROPIC_BASE_URL=http://localhost:4000 ANTHROPIC_MODEL=$model ANTHROPIC_SMALL_FAST_MODEL=$model claude --dangerously-skip-permissions"
}

# Claude Code Router with dynamic config generation and tmux integration
ccrcode() {
    # Get API keys from 1Password CLI
    local openrouter_key=$(op read op://Personal/Dev-API-KEY/openrouter-api-key)
    local groq_key=$(op read op://Personal/Dev-API-KEY/groq-api-key)
    
    # Ensure ~/.claude-code-router directory exists
    mkdir -p $HOME/.claude-code-router
    
    # Generate config.json from template with API key injection
    sed -e "s/OPENROUTER_API_KEY_PLACEHOLDER/$openrouter_key/g" \
        -e "s/GROQ_API_KEY_PLACEHOLDER/$groq_key/g" \
        "$HOME/.dotfiles/claude/claude-code-router/config.json" > "$HOME/.claude-code-router/config.json"
    
    # Launch with tmux development environment
    _create_dev_tmux_session "ccr code" "CCR" "$1"
}

# Claude Code + LiteLLM development environment with configurable model
cclitedev() {
    local model="${1:-openrouter/qwen/qwen3-coder}"  # Default to qwen3-coder
    local session_name="${2:-$(basename $(pwd) | sed 's/[^a-zA-Z0-9]/_/g')}"
    
    echo "🤖 Using model: $model"
    
    # Ensure LiteLLM is running
    _ensure_litellm_running || return 1
    
    # Create Claude Code command with specified model and launch in tmux
    local claude_command="$(_create_claude_litellm_command "$model")"
    _create_dev_tmux_session "$claude_command" "LiteLLM-$(echo $model | cut -d'/' -f3)" "$session_name"
}

# Modular tmux development environment function
_create_dev_tmux_session() {
    local ai_tool_command="$1"
    local ai_tool_name="${2:-AI}"
    local session_name="${3:-$(basename $(pwd) | sed 's/[^a-zA-Z0-9]/_/g')}"
    
    # Kill existing session if it exists
    tmux kill-session -t "$session_name" 2>/dev/null
    
    # Create new session with first pane
    tmux new-session -d -s "$session_name" -c "$(pwd)"
    
    # Create layout: split horizontally first
    tmux split-window -h -c "$(pwd)"
    
    # Split the left pane vertically
    tmux select-pane -t "$session_name.0"
    tmux split-window -v -c "$(pwd)"
    
    # Layout: pane 0 (lazygit), pane 1 (dev server), pane 2 (AI tool)
    sleep 0.1
    
    # Resize panes for optimal development layout
    tmux resize-pane -t "$session_name.0" -x 55%  # lazygit pane width
    tmux resize-pane -t "$session_name.0" -y 50%  # lazygit pane height
    tmux resize-pane -t "$session_name.1" -y 50%  # dev pane height
    tmux resize-pane -t "$session_name.2" -x 45%  # AI Development Tool width
    
    # Launch applications
    tmux send-keys -t "$session_name.0" 'lazygit' Enter
    tmux send-keys -t "$session_name.1" 'echo "run dev server here"' Enter
    tmux send-keys -t "$session_name.2" "$ai_tool_command" Enter
    
    # Focus on AI tool pane
    tmux select-pane -t "$session_name.2"
    
    # Attach to session
    tmux attach-session -t "$session_name"
}

# Claude Code development environment
ccdev() {
    _create_dev_tmux_session "claude --dangerously-skip-permissions" "Claude" "$1"
}

# Gemini CLI development environment
gdev() {
    _create_dev_tmux_session "gemini" "Gemini" "$1"
}

# OpenCode CLI development environment
opendev() {
    _create_dev_tmux_session "opencode" "OpenCode" "$1"
}

# OpenAI Codex CLI development environment
codexdev() {
    if [[ -z "$1" ]]; then
        _create_dev_tmux_session "codex" "Codex"
    else
        _create_dev_tmux_session "codex --profile \"$1\"" "Codex" "$1"
    fi
}

# LiteLLM Proxy Management
litellm-start() {
    local runtime_dir="$HOME/.litellm"
    local templates_dir="$HOME/.dotfiles/litellm"
    
    # Create runtime directory
    mkdir -p "$runtime_dir"
    
    # Check if templates directory exists
    if [[ ! -d "$templates_dir" ]]; then
        echo "❌ Templates directory not found: $templates_dir"
        return 1
    fi
    
    # Copy template files (excluding .env.template to avoid overwriting existing .env)
    echo "📋 Copying template files to $runtime_dir..."
    cp "$templates_dir"/config.yaml "$runtime_dir/" 2>/dev/null
    cp "$templates_dir"/README.md "$runtime_dir/" 2>/dev/null
    
    # Handle .env file - only create if it doesn't exist
    if [[ ! -f "$runtime_dir/.env" ]]; then
        if [[ -f "$templates_dir/.env.template" ]]; then
            cp "$templates_dir/.env.template" "$runtime_dir/.env"
            echo "📝 Created .env from template"
        else
            echo "❌ No .env.template found in $templates_dir"
            return 1
        fi
    else
        echo "✅ Using existing .env file"
    fi
    
    # Source environment variables
    source "$runtime_dir/.env"
    
    # Check if API key still contains placeholder or is empty
    if [[ "$OPENROUTER_API_KEY" == *"sk-or-v1-…"* ]] || [[ -z "$OPENROUTER_API_KEY" ]] || [[ "$OPENROUTER_API_KEY" == "sk-or-v1-…" ]]; then
        echo "🚩 Please replace the placeholder in $runtime_dir/.env:"
        echo "   Current: OPENROUTER_API_KEY=\"sk-or-v1-…\" # 🚩"
        echo "   Replace with your actual key from: https://openrouter.ai/keys"
        echo ""
        echo "💡 Would you like me to open the file for editing? (y/n)"
        read -q "?> " && echo && ${EDITOR:-nano} "$runtime_dir/.env"
        return 1
    fi
    
    # Validate API key format
    if [[ ! "$OPENROUTER_API_KEY" =~ ^sk-or-v1- ]]; then
        echo "⚠️  Warning: API key doesn't match expected OpenRouter format (should start with 'sk-or-v1-')"
        echo "   Current key: ${OPENROUTER_API_KEY:0:20}..."
        echo "   Continuing anyway, but this might cause authentication errors"
    fi
    
    # Check and validate GROQ_API_KEY
    if [[ "$GROQ_API_KEY" == *"gsk_…"* ]] || [[ -z "$GROQ_API_KEY" ]] || [[ "$GROQ_API_KEY" == "gsk_…" ]]; then
        echo "🚩 Groq API key not configured in $runtime_dir/.env:"
        echo "   Current: GROQ_API_KEY=\"gsk_…\" # 🚩"
        echo "   Replace with your actual key from: https://console.groq.com/keys"
        echo "   ⚠️  Groq models will not work without this key"
    elif [[ ! "$GROQ_API_KEY" =~ ^gsk_ ]]; then
        echo "⚠️  Warning: Groq API key doesn't match expected format (should start with 'gsk_')"
        echo "   Current key: ${GROQ_API_KEY:0:15}..."
    fi
    
    # Check and validate CEREBRAS_API_KEY
    if [[ "$CEREBRAS_API_KEY" == *"csk-…"* ]] || [[ -z "$CEREBRAS_API_KEY" ]] || [[ "$CEREBRAS_API_KEY" == "csk-…" ]]; then
        echo "🚩 Cerebras API key not configured in $runtime_dir/.env:"
        echo "   Current: CEREBRAS_API_KEY=\"csk-…\" # 🚩"
        echo "   Replace with your actual key from: https://cloud.cerebras.ai/"
        echo "   ⚠️  Cerebras models will not work without this key"
    elif [[ ! "$CEREBRAS_API_KEY" =~ ^csk- ]]; then
        echo "⚠️  Warning: Cerebras API key doesn't match expected format (should start with 'csk-')"
        echo "   Current key: ${CEREBRAS_API_KEY:0:15}..."
    fi
    
    # Start LiteLLM in tmux session
    echo "🚀 Starting LiteLLM proxy on port ${LITELLM_PORT:-4000}..."
    echo "   Config: $runtime_dir/config.yaml"
    echo "   API Key: ${OPENROUTER_API_KEY:0:15}... (✓ configured)"
    echo "   Running in tmux session 'litellm-server'..."
    
    # Kill existing litellm-server session if it exists
    tmux kill-session -t "litellm-server" 2>/dev/null || true
    
    # Create new tmux session for LiteLLM server
    tmux new-session -d -s "litellm-server" -c "$runtime_dir"
    
    # Set environment variables in the tmux session and start LiteLLM
    tmux send-keys -t "litellm-server" "export OPENROUTER_API_KEY='$OPENROUTER_API_KEY'" Enter
    tmux send-keys -t "litellm-server" "export GROQ_API_KEY='$GROQ_API_KEY'" Enter
    tmux send-keys -t "litellm-server" "export CEREBRAS_API_KEY='$CEREBRAS_API_KEY'" Enter
    tmux send-keys -t "litellm-server" "uvx 'litellm[proxy]@latest' --config config.yaml --port ${LITELLM_PORT:-4000} --host 0.0.0.0" Enter
    
    echo "✅ LiteLLM server started in background tmux session"
    echo "   View logs: tmux attach -t litellm-server"
    echo "   Detach from logs: Ctrl+B, then D"
}

litellm-stop() {
    echo "🛑 Stopping LiteLLM proxy..."
    
    # Kill the tmux session
    if tmux kill-session -t "litellm-server" 2>/dev/null; then
        echo "✅ LiteLLM tmux session 'litellm-server' stopped"
    else
        echo "ℹ️  No 'litellm-server' tmux session found"
    fi
    
    # Fallback: kill any remaining litellm processes
    pkill -f "litellm.*--config.*config.yaml" 2>/dev/null && echo "✅ Killed remaining LiteLLM processes" || true
}


# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source ~/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


# https://github.com/pyenv/pyenv/issues/1948
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# poetry
export PATH="$HOME/.local/bin:$PATH"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/bin/terraform terraform
export PATH="/usr/local/opt/openssl@3/bin:$PATH"





eval "$(direnv hook zsh)"

# Auto-Warpify
[[ "$-" == *i* ]] && printf 'P$f{"hook": "SourcedRcFileForWarp", "value": { "shell": "zsh", "uname": "Darwin" }}�' 

# bun completions
[ -s "/Users/memorysaver/.bun/_bun" ] && source "/Users/memorysaver/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# opencode
export PATH=/Users/memorysaver/.opencode/bin:$PATH


[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
