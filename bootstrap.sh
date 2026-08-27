#!/usr/bin/env bash
# Bootstrap dotfiles on a fresh machine
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/bootstrap.sh)"
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
REPO="https://github.com/memorysaver/dotfiles.git"

echo "=== Dotfiles Bootstrap ==="

# --- Detect platform ---
case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    if command -v omarchy >/dev/null 2>&1 || [ -r /etc/omarchy-release ]; then
      PLATFORM="omarchy"
    else
      distro="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-}")"
      distro_like="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID_LIKE:-}")"
      case " $distro $distro_like " in
        *" arch "*) PLATFORM="arch" ;;
        *" debian "*|*" ubuntu "*) PLATFORM="debian" ;;
        *) PLATFORM="unknown" ;;
      esac
    fi
    ;;
  *)      echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac
echo "Detected platform: $PLATFORM"

# --- Install foundation ---
if [ "$PLATFORM" = "macos" ]; then
  # Xcode CLI tools
  if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode CLI tools (accept the GUI dialog if it appears)..."
    xcode-select --install 2>/dev/null || true
    until xcode-select -p &>/dev/null; do
      sleep 10
    done
    echo "Xcode CLI tools installed."
  fi

  # Homebrew
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      echo "ERROR: brew not found after install" >&2
      exit 1
    fi
  fi
elif [ "$PLATFORM" = "omarchy" ]; then
  omarchy pkg add git curl wget base-devel
elif [ "$PLATFORM" = "arch" ]; then
  sudo pacman -S --needed git curl wget base-devel
elif [ "$PLATFORM" = "debian" ]; then
  sudo apt-get update -y
  sudo apt-get install -y git curl wget build-essential
else
  echo "Unsupported Linux distribution" >&2
  exit 1
fi

# --- Git ---
if ! command -v git &>/dev/null; then
  echo "Installing git..."
  if [ "$PLATFORM" = "macos" ]; then
    brew install git
  elif [ "$PLATFORM" = "omarchy" ]; then
    omarchy pkg add git
  elif [ "$PLATFORM" = "arch" ]; then
    sudo pacman -S --needed git
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

# --- Just (task runner) ---
if ! command -v just &>/dev/null; then
  echo "Installing just..."
  case "$PLATFORM" in
    macos) brew install just ;;
    omarchy) omarchy pkg add just ;;
    arch) sudo pacman -S --needed just ;;
    debian) curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | sudo bash -s -- --to /usr/local/bin ;;
  esac
fi

# --- Hand off to just ---
echo ""
echo "=== Running just setup ==="
cd "$DOTFILES_DIR"
just "setup-$PLATFORM"

echo ""
echo "=== Bootstrap complete! ==="
echo "Restart your shell or run: exec zsh"
