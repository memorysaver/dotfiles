# dotfiles
[![Built with Spacemacs](https://cdn.rawgit.com/syl20bnr/spacemacs/442d025779da2f62fc86c2082703697714db6514/assets/spacemacs-badge.svg)](http://spacemacs.org)

## Prerequisites

Before running the dotfiles installation script, you need to install the following tools and dependencies:

### 1. Core System Tools

#### Homebrew (macOS Package Manager)
```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# For Apple Silicon Macs (M1/M2/M3/M4), add to PATH
echo 'export PATH=/opt/homebrew/bin:$PATH' >> ~/.zshrc
source ~/.zshrc

# Verify installation
brew --version
```

#### Git
```bash
# macOS (via Homebrew)
brew install git

# Ubuntu/Debian
sudo apt update && sudo apt install git

# Verify installation
git --version
```

#### Zsh & Oh-My-Zsh
```bash
# Install Zsh
# macOS
brew install zsh

# Ubuntu/Debian
sudo apt install zsh

# Make Zsh default shell
chsh -s $(which zsh)

# Install Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install essential plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

### 2. Development Languages & Runtimes

#### Node.js & npm
```bash
# Install nvm (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.zshrc

# Install latest LTS Node.js
nvm install --lts
nvm use --lts

# Verify installation
node --version
npm --version
```

#### Rust & Cargo
```bash
# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version
```

#### Python & Pyenv & Poetry & UV
```bash
# Install pyenv
curl https://pyenv.run | bash

# Install Poetry via pipx
sudo apt install pipx  # Ubuntu/Debian
pipx install poetry

# Configure Poetry
poetry config virtualenvs.in-project true
poetry config virtualenvs.prefer-active-python true

# Install UV (extremely fast Python package manager)
# Using standalone installer (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or using pipx
pipx install uv

# Or using Homebrew on macOS
brew install uv

# Verify installation
pyenv --version
poetry --version
uv --version
```

### 3. Development Tools

#### tmux
```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Verify installation
tmux -V
```

#### Lazygit
```bash
# macOS
brew install lazygit

# Ubuntu/Debian
sudo add-apt-repository ppa:lazygit-team/daily
sudo apt update
sudo apt install lazygit

# Verify installation
lazygit --version
```

#### GitHub CLI
```bash
# macOS
brew install gh

# Ubuntu/Debian (Official APT Repository - Recommended)
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
&& sudo mkdir -p -m 755 /etc/apt/keyrings \
&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
&& sudo apt update \
&& sudo apt install gh -y

# Authenticate with GitHub
gh auth login

# Verify installation
gh --version
```

#### Neovim
```bash
# macOS
brew install neovim

# Ubuntu/Debian
sudo apt install neovim

# Verify installation
nvim --version
```

#### Direnv
```bash
# macOS
brew install direnv

# Ubuntu/Debian
sudo apt install direnv

# Add to shell configuration
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
source ~/.zshrc

# Verify installation
direnv --version
```

#### Terraform
```bash
# macOS
brew install terraform

# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Verify installation
terraform --version
```

### 4. AI Development Tools

#### Claude Code
```bash
# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version
```

#### Gemini CLI
```bash
# Install Gemini CLI
npm install -g @google/gemini-cli

# Verify installation
gemini --version
```

#### OpenCode CLI
```bash
# Install OpenCode CLI
curl -fsSL https://opencode.ai/install | bash

# Or using Homebrew on macOS
brew install sst/tap/opencode

# Verify installation
opencode --version
```

### 5. Optional Tools

#### Emacs (for Spacemacs)
```bash
# macOS
brew install emacs

# Ubuntu/Debian
sudo apt install emacs

# Verify installation
emacs --version
```

#### Bun (JavaScript Runtime)
```bash
# Install Bun
curl -fsSL https://bun.sh/install | bash

# Verify installation
bun --version
```

## Installation Guide

After installing all prerequisites, run the dotfiles installation script:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/install.sh)"
```

### Setup Github

```bash

# copy ssh key to clipboard for adding to github.com
pbcopy < ~/.ssh/id_rsa.pub

# test connection
ssh -T git@github.com
```

### Install Spacemacs

```bash
git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d
apt-get install emacs
```

### Configure tmux

Modern tmux configuration with ergonomic key bindings and visual improvements:

```bash
# Configuration is managed in dotfiles
ln -sf ~/.dotfiles/.tmux.conf ~/.tmux.conf

# Reload configuration in existing tmux session
tmux source-file ~/.tmux.conf

# Codex CLI configuration
mkdir -p ~/.codex
ln -sf ~/.dotfiles/openai-codex/config.toml ~/.codex/config.toml
```

**Key Features:**
- Prefix key: `Ctrl+a` (instead of `Ctrl+b`)
- Split panes: `Ctrl+a |` (horizontal) and `Ctrl+a -` (vertical)
- Navigate panes: `Alt+arrows` or `Ctrl+a hjkl`
- Reload config: `Ctrl+a r`
- Mouse support enabled
- Tokyo Night color scheme

### AI-Powered Development Environments

#### Claude Code Development Environment

The `ccdev` function creates a tmux development environment optimized for Claude Code:


```bash
# Install Claude Code first
npm install -g @anthropic-ai/claude-code
```


```bash
# Launch Claude development environment
ccdev [session-name]

# If no session name provided, uses current directory name
ccdev my-project
```

#### Gemini CLI Development Environment

The `gdev` function creates a tmux development environment with Gemini CLI:

```bash
# Install Gemini CLI first
npm install -g @google/gemini-cli

# Launch Gemini development environment
gdev [session-name]
```

#### OpenCode CLI Development Environment

The `opendev` function creates a tmux development environment with OpenCode CLI:

```bash
# Install OpenCode CLI first
curl -fsSL https://opencode.ai/install | bash

# or Using Homebrew on macOS

brew install sst/tap/opencode

# Launch OpenCode development environment
opendev [session-name]
```

#### OpenAI Codex CLI Development Environment

The `codexdev` function creates a tmux development environment with the OpenAI Codex CLI:

```bash
# Install OpenAI Codex CLI first
npm install -g @openai/codex

# Launch Codex development environment
codexdev [session-name]
```

All environments create a multi-pane workspace with:
- **Top-Left pane (55% width)**: Lazygit for version control
- **Bottom-left pane (55% width)**: Development server
- **Right pane (45% width)**: AI assistant (Claude, Gemini, or OpenCode)
