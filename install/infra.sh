#!/usr/bin/env bash
# Install infrastructure tools: Terraform, Pulumi, SST (opt-in)
source "$(dirname "$0")/../lib/helpers.sh"

info "Installing infrastructure tools..."

# --- Terraform ---
if ! has terraform; then
  info "Installing Terraform..."
  case "$DOTFILES_OS" in
    macos) brew install terraform ;;
    linux)
      wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
      sudo apt-get update && sudo apt-get install -y terraform
      ;;
  esac
else
  ok "Terraform already installed"
fi

# --- Pulumi ---
if ! has pulumi; then
  info "Installing Pulumi..."
  curl -fsSL https://get.pulumi.com | sh
else
  ok "Pulumi already installed"
fi

# --- SST ---
if ! has sst; then
  info "Installing SST..."
  curl -fsSL https://sst.dev/install | bash
else
  ok "SST already installed"
fi

ok "Infrastructure tools installation complete"
