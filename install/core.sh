#!/usr/bin/env bash
# Install core tools: zsh, oh-my-zsh, tmux, starship, nvim, lazygit, git, direnv
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing core tools..."

# --- Zsh ---
ensure_installed zsh zsh zsh

# --- Oh-My-Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  info "Installing Oh-My-Zsh..."
  RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh-My-Zsh installed"
else
  ok "Oh-My-Zsh already installed"
fi

# --- Zsh plugins ---
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

zsh_plugins=(
  zsh-autosuggestions
  zsh-syntax-highlighting
)

for plugin in "${zsh_plugins[@]}"; do
  if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
    info "Installing $plugin..."
    git clone --depth=1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
  else
    ok "$plugin already installed"
  fi
done

# --- Starship prompt ---
if ! has starship; then
  info "Installing starship..."
  case "$DOTFILES_OS" in
    macos) brew install starship ;;
    linux) curl -sS https://starship.rs/install.sh | sh -s -- -y ;;
  esac
else
  ok "starship already installed"
fi

# --- tmux ---
ensure_installed tmux tmux tmux

# --- Neovim ---
ensure_installed nvim neovim neovim

# --- Lazygit ---
if ! has lazygit; then
  info "Installing lazygit..."
  case "$DOTFILES_OS" in
    macos) brew install lazygit ;;
    linux)
      LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
      ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64"
      curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_${ARCH}.tar.gz"
      sudo tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
      rm /tmp/lazygit.tar.gz
      ;;
  esac
else
  ok "lazygit already installed"
fi

# --- Git ---
ensure_installed git git git

# --- Direnv ---
ensure_installed direnv direnv direnv

ok "Core tools installation complete"
