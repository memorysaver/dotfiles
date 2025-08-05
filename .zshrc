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

# Claude Code alias
alias ccusage="ccusage blocks --live"

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
