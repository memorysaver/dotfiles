#!/usr/bin/env bash
# Install CLI tools: gh, glab, jq, yq, just, agent-browser, portless
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing CLI tools..."

# --- GitHub CLI ---
if ! has gh; then
  info "Installing GitHub CLI..."
  case "$DOTFILES_OS" in
    macos) brew install gh ;;
    linux)
      (type -p wget >/dev/null || sudo apt-get install -y wget) \
        && sudo mkdir -p -m 755 /etc/apt/keyrings \
        && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
        && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
        && sudo apt-get update && sudo apt-get install -y gh
      ;;
  esac
else
  ok "gh already installed"
fi

# --- GitLab CLI ---
if ! has glab; then
  info "Installing GitLab CLI..."
  case "$DOTFILES_OS" in
    macos) brew install glab ;;
    linux)
      # Install via official script
      curl -fsSL https://raw.githubusercontent.com/profclems/glab/trunk/scripts/install.sh | sudo sh
      ;;
  esac
else
  ok "glab already installed"
fi

# --- jq ---
ensure_installed jq jq jq

# --- yq ---
if ! has yq; then
  info "Installing yq..."
  case "$DOTFILES_OS" in
    macos) brew install yq ;;
    linux)
      YQ_VERSION=$(curl -s "https://api.github.com/repos/mikefarah/yq/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
      curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
      sudo chmod +x /usr/local/bin/yq
      ;;
  esac
else
  ok "yq already installed"
fi

# --- Just (task runner) ---
if ! has just; then
  info "Installing just..."
  case "$DOTFILES_OS" in
    macos) brew install just ;;
    linux)
      curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
      ;;
  esac
else
  ok "just already installed"
fi

# --- Agent Browser (Vercel) ---
if ! has agent-browser; then
  info "Installing agent-browser..."
  if has npm; then
    npm install -g @anthropic-ai/agent-browser
  else
    warn "npm not found — skipping agent-browser"
  fi
else
  ok "agent-browser already installed"
fi

# --- Portless (Vercel) ---
if ! has portless; then
  info "Installing portless..."
  if has npm; then
    npm install -g @anthropic-ai/portless
  else
    warn "npm not found — skipping portless"
  fi
else
  ok "portless already installed"
fi

ok "CLI tools installation complete"
