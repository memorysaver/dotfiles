#!/usr/bin/env bash
# Install CLI tools: gh, glab, jq, yq, just, mail tools, agent-browser, portless;
# macOS-only additions: cliamp, lazydocker, mole
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
    debian|grok-bot)
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
    debian|grok-bot)
      # GitLab publishes Go-style arch names (amd64/arm64), not uname -m's
      # x86_64/aarch64. A wrong name returns a small HTML 404 page, so fetch
      # with -f, verify the archive, and only warn on failure so the rest of
      # tools.sh (yq, just, hyperframes, ...) still runs.
      install_glab_tarball() {
        local version arch tmp
        case "$(uname -m)" in
          x86_64|amd64) arch=amd64 ;;
          aarch64|arm64) arch=arm64 ;;
          *) warn "glab: unsupported architecture $(uname -m)"; return 1 ;;
        esac
        version=$(curl -fsSL "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest" \
          | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null) || version=""
        [ -n "$version" ] || { warn "glab: could not resolve the latest release"; return 1; }
        tmp=$(mktemp -d)
        if retry 3 2 curl -fsSLo "$tmp/glab.tar.gz" \
             "https://gitlab.com/gitlab-org/cli/-/releases/${version}/downloads/glab_${version#v}_linux_${arch}.tar.gz" \
           && tar tzf "$tmp/glab.tar.gz" bin/glab >/dev/null 2>&1 \
           && tar xzf "$tmp/glab.tar.gz" -C "$tmp" bin/glab \
           && sudo install -m 755 "$tmp/bin/glab" /usr/local/bin/glab; then
          rm -rf "$tmp"
          ok "glab ${version#v} installed"
        else
          rm -rf "$tmp"
          warn "glab ${version} download failed; skipping"
          return 1
        fi
      }
      install_glab_tarball || true
      ;;
  esac
else
  ok "glab already installed"
fi

# --- jq ---
ensure_installed jq jq jq

# --- yq ---
if ! has_working yq; then
  info "Installing yq..."
  case "$DOTFILES_PLATFORM" in
    macos) brew install yq ;;
    omarchy) omarchy pkg add yq ;;
    arch) sudo pacman -S --needed --noconfirm yq ;;
    debian|grok-bot)
      # Same arch-name trap as glab: yq assets use amd64/arm64. Download to a
      # temp file and only install a binary that actually runs, so a 404 page
      # never lands in /usr/local/bin/yq.
      install_yq_binary() {
        local version arch tmp
        case "$(uname -m)" in
          x86_64|amd64) arch=amd64 ;;
          aarch64|arm64) arch=arm64 ;;
          *) warn "yq: unsupported architecture $(uname -m)"; return 1 ;;
        esac
        version=$(curl -fsSL "https://api.github.com/repos/mikefarah/yq/releases/latest" \
          | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])" 2>/dev/null) || version=""
        [ -n "$version" ] || { warn "yq: could not resolve the latest release"; return 1; }
        tmp=$(mktemp -d)
        if retry 3 2 curl -fsSLo "$tmp/yq" \
             "https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${arch}" \
           && chmod +x "$tmp/yq" && "$tmp/yq" --version >/dev/null 2>&1 \
           && sudo install -m 755 "$tmp/yq" /usr/local/bin/yq; then
          rm -rf "$tmp"
          ok "yq ${version} installed"
        else
          rm -rf "$tmp"
          warn "yq ${version} download failed; skipping"
          return 1
        fi
      }
      install_yq_binary || true
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
    debian|grok-bot)
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

# --- Cliamp + Lazydocker (macOS-only terminal tools) ---
if [ "$DOTFILES_PLATFORM" = macos ]; then
  if ! has cliamp; then
    info "Installing cliamp..."
    brew install bjarneo/cliamp/cliamp
  else
    ok "cliamp already installed"
  fi

  if ! has lazydocker; then
    info "Installing lazydocker..."
    brew install lazydocker
  else
    ok "lazydocker already installed"
  fi
else
  ok "cliamp and lazydocker are macOS-only -- skipping"
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

# --- Hyperframes (Grok Bot Short / video compositions) ---
# npm package requires Node >= 22. Install only on grok-bot; James Cameron /
# short-builder need `hyperframes` on PATH after Update Computer. Do not use
# ephemeral file:/tmp/*.tgz installs.
if [ "$DOTFILES_PLATFORM" = grok-bot ]; then
  if has_working hyperframes; then
    ok "hyperframes already installed ($(hyperframes --version 2>/dev/null | head -1))"
  elif ! has npm && ! [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    warn "npm/nvm not found — skipping hyperframes"
  else
    info "Installing hyperframes (Node >= 22)..."
    (
      set +u
      unset NPM_CONFIG_PREFIX
      NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
      if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        . "$NVM_DIR/nvm.sh"
        nvm install 22 >/dev/null
        nvm use 22 >/dev/null
      fi
      major="$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)"
      if [ "${major:-0}" -lt 22 ]; then
        warn "hyperframes needs Node >= 22 (have $(node --version 2>/dev/null || echo none)) — skipping"
        exit 0
      fi
      npm install -g hyperframes
      # Durable PATH entry for agent shells that may not load nvm
      mkdir -p "$HOME/.local/bin"
      node_bin="$(command -v node)"
      hf_mjs="$(node -p "require('path').join(require('path').dirname(process.execPath), '../lib/node_modules/hyperframes/bin/hyperframes.mjs')" 2>/dev/null || true)"
      if [ ! -f "$hf_mjs" ]; then
        hf_mjs="$(npm root -g)/hyperframes/bin/hyperframes.mjs"
      fi
      if [ -f "$hf_mjs" ]; then
        cat >"$HOME/.local/bin/hyperframes" <<EOF
#!/usr/bin/env bash
unset NPM_CONFIG_PREFIX
export NVM_DIR="\${NVM_DIR:-\$HOME/.nvm}"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
nvm use 22 >/dev/null 2>&1 || true
exec node "$hf_mjs" "\$@"
EOF
        chmod +x "$HOME/.local/bin/hyperframes"
      fi
      if has_working hyperframes; then
        ok "hyperframes installed ($(hyperframes --version 2>/dev/null | head -1))"
      else
        warn "hyperframes install finished but --version failed"
      fi
    ) || warn "hyperframes install failed"
  fi
fi

# Skill-backing CLIs (opencli, podwise, wavespeed-cli, qmd, uipro-cli) are no longer
# installed globally on every machine. Each existed only to make one skill in
# agents/skills/ runnable, so they belong wherever that skill is actually used.
# docs/removed-agent-clis.md records every one and the command to bring it back.

ok "CLI tools installation complete"
