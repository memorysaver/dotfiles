#!/usr/bin/env bash
# Shared helper functions for idempotent dotfiles installation
# Source this file: source "$(dirname "$0")/../lib/helpers.sh"

set -euo pipefail

# --- OS Detection ---
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unknown" ;;
  esac
}

DOTFILES_OS="${DOTFILES_OS:-$(detect_os)}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# --- Logging ---
info()  { printf '  \033[34m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# --- Idempotent Helpers ---

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Install a package if the command is not already available
# Usage: ensure_installed <command_name> <brew_pkg> [apt_pkg]
# If apt_pkg is omitted, uses brew_pkg name
ensure_installed() {
  local cmd="$1" brew_pkg="$2" apt_pkg="${3:-$2}"
  if has "$cmd"; then
    ok "$cmd already installed"
    return 0
  fi
  info "Installing $cmd..."
  pkg_install "$brew_pkg" "$apt_pkg"
}

# Install a package via the OS package manager
# Usage: pkg_install <brew_pkg> [apt_pkg]
pkg_install() {
  local brew_pkg="$1" apt_pkg="${2:-$1}"
  case "$DOTFILES_OS" in
    macos) brew install "$brew_pkg" ;;
    linux) sudo apt-get install -y "$apt_pkg" ;;
    *)     fail "Unsupported OS: $DOTFILES_OS"; return 1 ;;
  esac
}

# Create a symlink only if it doesn't already point to the right target
# Usage: ensure_symlink <source> <destination>
ensure_symlink() {
  local src="$1" dest="$2"
  # Create parent directory if needed
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "$(basename "$dest") already linked"
    return 0
  fi
  # Remove existing file/symlink/directory at dest
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    rm -rf "$dest"
  fi
  ln -s "$src" "$dest"
  ok "Linked $(basename "$dest") → $src"
}

# Ensure a directory exists
ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    return 0
  fi
  mkdir -p "$dir"
  ok "Created $dir"
}
