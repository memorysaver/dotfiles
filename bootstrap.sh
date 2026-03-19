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
