#!/usr/bin/env bash
# Shared helper functions for idempotent dotfiles installation
# Source this file: source "$(dirname "$0")/../lib/helpers.sh"

set -euo pipefail

# --- Platform Detection ---
# Keep distributions separate: package names and ownership conventions differ.
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "macos"; return ;;
    Linux) ;;
    *) echo "unknown"; return ;;
  esac

  if command -v omarchy >/dev/null 2>&1 || [ -r /etc/omarchy-release ]; then
    echo "omarchy"
    return
  fi

  local distro="" distro_like=""
  if [ -r /etc/os-release ]; then
    distro="$(. /etc/os-release; printf '%s' "${ID:-}")"
    distro_like="$(. /etc/os-release; printf '%s' "${ID_LIKE:-}")"
  fi

  case " $distro $distro_like " in
    *" arch "*) echo "arch" ;;
    *" debian "*|*" ubuntu "*) echo "debian" ;;
    *) echo "unknown" ;;
  esac
}

DOTFILES_PLATFORM="${DOTFILES_PLATFORM:-${DOTFILES_OS:-$(detect_platform)}}"
# Compatibility for older scripts while they migrate to DOTFILES_PLATFORM.
DOTFILES_OS="$DOTFILES_PLATFORM"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

# --- Logging ---
info()  { printf '  \033[34m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; }

# --- Idempotent Helpers ---

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# A shim can exist while its backing tool is absent (Mise behaves this way).
has_working() {
  command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

# Install a package if the command is not already available
# Usage: ensure_installed <command> <brew_pkg> [debian_pkg] [arch_pkg]
ensure_installed() {
  local cmd="$1" brew_pkg="$2" debian_pkg="${3:-$2}" arch_pkg="${4:-${3:-$2}}"
  if has "$cmd"; then
    ok "$cmd already installed"
    return 0
  fi
  info "Installing $cmd..."
  pkg_install "$brew_pkg" "$debian_pkg" "$arch_pkg"
}

# Install a package via the OS package manager
# Usage: pkg_install <brew_pkg> [debian_pkg] [arch_pkg]
pkg_install() {
  local brew_pkg="$1" debian_pkg="${2:-$1}" arch_pkg="${3:-${2:-$1}}"
  case "$DOTFILES_PLATFORM" in
    macos) brew install "$brew_pkg" ;;
    omarchy) omarchy pkg add "$arch_pkg" ;;
    arch) sudo pacman -S --needed --noconfirm "$arch_pkg" ;;
    debian) sudo apt-get install -y "$debian_pkg" ;;
    *) fail "Unsupported platform: $DOTFILES_PLATFORM"; return 1 ;;
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
  # Never silently destroy a user's existing configuration.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    case "${DOTFILES_LINK_MODE:-refuse}" in
      backup)
        local backup="${dest}.pre-dotfiles.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        warn "Backed up $dest to $backup"
        ;;
      replace)
        rm -rf -- "$dest"
        ;;
      *)
        warn "Refusing to replace existing path: $dest"
        warn "Review it, then rerun with DOTFILES_LINK_MODE=backup (recommended)"
        return 1
        ;;
    esac
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
