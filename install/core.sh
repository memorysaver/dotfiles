#!/usr/bin/env bash
# Install the platform shell plus tmux, starship, nvim, lazygit, git, direnv,
# and macOS-only Ghostty/font dependencies.
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing core tools..."

# --- macOS shell: Zsh + Oh My Zsh ---
# Omarchy keeps its Bash shell so its defaults remain available.
if [ "$DOTFILES_PLATFORM" != "omarchy" ]; then
  ensure_installed zsh zsh zsh

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh-My-Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh-My-Zsh installed"
  else
    ok "Oh-My-Zsh already installed"
  fi

  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ ! -d "$ZSH_CUSTOM/plugins/$plugin" ]; then
      info "Installing $plugin..."
      git clone --depth=1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
    else
      ok "$plugin already installed"
    fi
  done
else
  ok "Omarchy: keeping Bash; Zsh and Oh My Zsh skipped"
fi

# --- Starship prompt ---
ensure_installed starship starship starship starship

# --- tmux ---
ensure_installed tmux tmux tmux

# --- Neovim ---
ensure_installed nvim neovim neovim

# --- Lazygit ---
if ! has lazygit; then
  info "Installing lazygit..."
  case "$DOTFILES_PLATFORM" in
    macos) brew install lazygit ;;
    omarchy) omarchy pkg add lazygit ;;
    arch) sudo pacman -S --needed --noconfirm lazygit ;;
    debian)
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
ensure_installed git-lfs git-lfs git-lfs git-lfs

# --- Direnv ---
ensure_installed direnv direnv direnv

# --- Ghostty (macOS; terminal emulator, config linked by `just link`) ---
# The cask is marked auto_updates, so Homebrew installs the current release once
# and Ghostty's own Sparkle updater keeps it there. The Caskroom directory stays
# pinned to whatever version was first installed while the app moves ahead on its
# own -- that gap is expected and `brew upgrade` is a no-op, so don't chase it
# with a reinstall (which would swap the bundle out from under a running session).
if [ "$DOTFILES_PLATFORM" = "macos" ]; then
  if ! brew list --cask ghostty &>/dev/null; then
    info "Installing Ghostty..."
    brew install --cask ghostty
  else
    ok "Ghostty already installed"
  fi
else
  ok "Ghostty skipped (macOS only)"
fi

# --- JetBrainsMono Nerd Font (macOS; used by terminal, starship, lazygit) ---
if [ "$DOTFILES_PLATFORM" = "macos" ]; then
  if ! brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
    info "Installing JetBrainsMono Nerd Font..."
    brew install --cask font-jetbrains-mono-nerd-font
  else
    ok "JetBrainsMono Nerd Font already installed"
  fi
else
  ok "JetBrainsMono Nerd Font skipped (macOS only)"
fi

# --- Sarasa Gothic (macOS; CJK fallback named in the macOS Ghostty config) ---
# JetBrains Mono has no CJK coverage, so without this the terminal falls back per
# codepoint across whatever Han fonts macOS ships and the weight visibly jumps
# between characters. Sarasa keeps CJK at exactly 2x the ASCII advance.
if [ "$DOTFILES_PLATFORM" = "macos" ]; then
  if ! brew list --cask font-sarasa-gothic &>/dev/null; then
    info "Installing Sarasa Gothic (CJK)..."
    brew install --cask font-sarasa-gothic
  else
    ok "Sarasa Gothic already installed"
  fi
else
  ok "Sarasa Gothic skipped (macOS only)"
fi

ok "Core tools installation complete"
