#!/usr/bin/env bash
# Install CLI tools: gh, glab, jq, yq, just, mail tools, agent-browser, portless, mole (macOS)
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing CLI tools..."

# --- GitHub CLI ---
if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  # Always refresh the wrapper: a system gh or an older standalone binary must
  # not prevent a restored Omarchy machine from adopting Mise ownership.
  omarchy-mise-install gh
  ok "gh managed by Omarchy + Mise"
elif ! has_working gh; then
  info "Installing GitHub CLI..."
  case "$DOTFILES_PLATFORM" in
    macos) brew install gh ;;
    arch) sudo pacman -S --needed --noconfirm github-cli ;;
    debian)
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
if ! has_working glab; then
  info "Installing GitLab CLI..."
  case "$DOTFILES_PLATFORM" in
    macos) brew install glab ;;
    omarchy) omarchy pkg add glab ;;
    arch) sudo pacman -S --needed --noconfirm glab ;;
    debian)
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
  case "$DOTFILES_PLATFORM" in
    macos) brew install yq ;;
    omarchy) omarchy pkg add yq ;;
    arch) sudo pacman -S --needed --noconfirm yq ;;
    debian)
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
  case "$DOTFILES_PLATFORM" in
    macos) brew install just ;;
    omarchy) omarchy pkg add just ;;
    arch) sudo pacman -S --needed --noconfirm just ;;
    debian)
      curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin
      ;;
  esac
else
  ok "just already installed"
fi

# --- Agent mail tools ---
if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  omarchy pkg add himalaya
  omarchy-mise-install cargo:ortie ortie
  ok "Himalaya and Ortie managed by Omarchy"
elif ! has himalaya || ! has ortie; then
  warn "Himalaya/Ortie are configured automatically on Omarchy only"
else
  ok "Himalaya and Ortie already installed"
fi

# --- Agent Browser (Vercel) ---
if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  omarchy-mise-install npm:agent-browser agent-browser
  ok "agent-browser managed by Omarchy + Mise"
elif ! has agent-browser; then
  info "Installing agent-browser..."
  if has npm; then
    npm install -g agent-browser || warn "agent-browser install failed"
  else
    warn "npm not found — skipping agent-browser"
  fi
else
  ok "agent-browser already installed"
fi

# --- Portless (Vercel) ---
if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  omarchy-mise-install npm:portless portless
  ok "portless managed by Omarchy + Mise"
elif ! has portless; then
  info "Installing portless..."
  if has npm; then
    npm install -g portless || warn "portless install failed"
  else
    warn "npm not found — skipping portless"
  fi
else
  ok "portless already installed"
fi

# --- Mole --- macOS system maintenance: clean, uninstall, analyze, monitor
# The binary is `mole`, with `mo` symlinked at it; both land in the prefix.
# macOS only, and not by our choice: the homebrew-core formula declares
# `depends_on :macos`, so the Linux arm every other tool here carries would just
# fail. Same shape as the Ghostty gate in core.sh -- install and check stay on
# the same platform, so the repo never points at something it would not install.
if ! has mole; then
  case "$DOTFILES_PLATFORM" in
    macos)
      info "Installing Mole..."
      brew install mole
      ;;
    *) ok "Mole is macOS-only -- skipping" ;;
  esac
else
  # `mole --version` opens with a blank line, so match the version line by name.
  ok "Mole already installed ($(mole --version 2>/dev/null | awk '/^Mole version/{print $3; exit}'))"
fi

# Skill-backing CLIs (opencli, podwise, wavespeed-cli, qmd, uipro-cli) are no longer
# installed globally on every machine. Each existed only to make one skill in
# agents/skills/ runnable, so they belong wherever that skill is actually used.
# docs/removed-agent-clis.md records every one and the command to bring it back.

ok "CLI tools installation complete"
