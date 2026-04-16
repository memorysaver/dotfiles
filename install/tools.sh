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
      GLAB_VERSION=$(curl -s "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['tag_name'])")
      ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64"
      curl -Lo /tmp/glab.tar.gz "https://gitlab.com/gitlab-org/cli/-/releases/${GLAB_VERSION}/downloads/glab_${GLAB_VERSION#v}_linux_${ARCH}.tar.gz"
      sudo tar xf /tmp/glab.tar.gz -C /usr/local/bin --strip-components=1 bin/glab
      rm /tmp/glab.tar.gz
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
      ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH="arm64"
      sudo curl -Lo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}"
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
    npm install -g @anthropic-ai/agent-browser || warn "agent-browser not available on npm — skipping"
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
    npm install -g @anthropic-ai/portless || warn "portless not available on npm — skipping"
  else
    warn "npm not found — skipping portless"
  fi
else
  ok "portless already installed"
fi

# --- opencli (jackwener) ---
if ! has opencli; then
  info "Installing opencli..."
  if has npm; then
    npm install -g @jackwener/opencli || warn "opencli install failed — skipping"
  else
    warn "npm not found — skipping opencli"
  fi
else
  ok "opencli already installed"
fi

# --- podwise-cli (hardhackerlabs) ---
if ! has podwise; then
  info "Installing podwise-cli..."
  case "$DOTFILES_OS" in
    macos) brew install hardhackerlabs/podwise-tap/podwise ;;
    linux) warn "podwise-cli has no Linux package — install manually from https://github.com/hardhackerlabs/podwise-cli" ;;
  esac
else
  ok "podwise already installed"
fi

# --- wavespeed-cli (local) ---
if ! has wavespeed; then
  info "Installing wavespeed-cli..."
  if has npm; then
    npm install -g "$DOTFILES_DIR/tools/wavespeed-cli" || warn "wavespeed-cli install failed — skipping"
  else
    warn "npm not found — skipping wavespeed-cli"
  fi
else
  ok "wavespeed already installed"
fi

# --- qmd (Quick Markdown Search) — memory backbone for the lesson-learned skill ---
if ! has qmd; then
  info "Installing qmd..."
  if has bun; then
    bun install -g @tobilu/qmd || warn "qmd install failed — skipping"
  elif has npm; then
    npm install -g @tobilu/qmd || warn "qmd install failed — skipping"
  else
    warn "neither bun nor npm found — skipping qmd"
  fi
else
  ok "qmd already installed"
fi

ok "CLI tools installation complete"
