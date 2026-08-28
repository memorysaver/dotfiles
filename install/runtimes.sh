#!/usr/bin/env bash
# Install language runtimes: pyenv, uv, nvm, Node.js, Bun, Rust
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing language runtimes..."

# Omarchy ships Mise and uses it as the single runtime manager. Keep Arch-based
# machines on the same model instead of layering pyenv, nvm, and rustup on top.
if [ "$DOTFILES_PLATFORM" = "omarchy" ] || [ "$DOTFILES_PLATFORM" = "arch" ]; then
  if ! has mise; then
    if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
      omarchy pkg add mise-bin
    else
      sudo pacman -S --needed --noconfirm mise
    fi
  fi

  info "Installing runtimes with Mise..."
  if [ "$DOTFILES_PLATFORM" = "omarchy" ]; then
    # Omarchy provisions current Node, not the LTS channel. Preserve that
    # default while adding the personal cross-platform runtime set.
    retry 3 5 mise use --global node@latest python@latest rust@stable bun@latest uv@latest
  else
    retry 3 5 mise use --global node@lts python@latest rust@stable bun@latest uv@latest
  fi
  ok "Language runtimes managed by Mise"
  exit 0
fi

# --- Pyenv ---
if ! has pyenv; then
  info "Installing pyenv..."
  curl https://pyenv.run | bash
else
  ok "pyenv already installed"
fi

# --- UV (Python package manager) ---
if ! has uv; then
  info "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  ok "uv already installed"
fi

# --- NVM + Node.js ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -d "$NVM_DIR" ]; then
  info "Installing nvm..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
  ok "nvm already installed"
fi
# Source nvm for this script
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if ! has node; then
  info "Installing Node.js LTS..."
  nvm install --lts
else
  ok "Node.js already installed ($(node --version))"
fi

# --- Bun ---
if ! has bun; then
  info "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
else
  ok "Bun already installed"
fi

# --- Rust ---
if ! has rustc; then
  info "Installing Rust..."
  curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
else
  ok "Rust already installed"
fi

ok "Language runtimes installation complete"
