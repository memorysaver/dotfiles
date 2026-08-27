# ~/.zshenv — managed by ~/.dotfiles
# Source: config/zsh/.zshenv

# Non-interactive shells used by automation do not always run ~/.zshrc.
case "$(uname -s)" in
  Darwin)
    export BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
    export PATH="$BREW_PREFIX/bin:/usr/local/bin:$PATH"
    ;;
  Linux)
    export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"
    ;;
esac
