# ~/.zshenv — managed by ~/.dotfiles
# Source: config/zsh/.zshenv

# Non-interactive shells used by automation do not always run ~/.zshrc.
# Keep Homebrew's prefix available for tools that load Homebrew libraries.
export BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
