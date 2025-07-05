#!/usr/bin/env bash

if [ ! -d "$HOME/.dotfiles" ]; then
  git clone https://github.com/memorysaver/dotfiles.git ~/.dotfiles
fi

# initialize and update git submodules (for SuperClaude)
cd ~/.dotfiles
git submodule update --init --recursive
# Also pull latest changes if already initialized
git submodule update --remote claude/superclaude

# symlinks for dotfiles
ln -sfv "$HOME/.dotfiles/.spacemacs" ~
ln -sfv "$HOME/.dotfiles/.zshrc" ~
ln -sfv "$HOME/.dotfiles/.tmux.conf" ~
ln -sfv "$HOME/.dotfiles/git/.gitconfig" ~
ln -sfv "$HOME/.dotfiles/git/.gitmessage" ~
# Create nvim config symlink (avoid recursive symlink)
if [ -L ~/.config/nvim ] && [ "$(readlink ~/.config/nvim)" = "$HOME/.dotfiles/nvim" ]; then
  echo "~/.config/nvim already correctly linked"
else
  # Remove existing nvim config if it exists
  [ -e ~/.config/nvim ] && rm -rf ~/.config/nvim
  ln -sfv "$HOME/.dotfiles/nvim" ~/.config/nvim
fi

# setup lazygit config
mkdir -p "$HOME/Library/Application Support/lazygit"
ln -sfv "$HOME/.dotfiles/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"

# setup SuperClaude (install or update)
echo "Setting up SuperClaude..."
cd "$HOME/.dotfiles/claude/superclaude"
./install.sh --force
cd ~/.dotfiles

# setup claude commands directory and symlinks for personal commands
mkdir -p ~/.claude/commands
for file in "$HOME/.dotfiles/claude/commands"/*; do
  if [ -f "$file" ]; then
    ln -sfv "$file" ~/.claude/commands/
  fi
done

# setup SuperClaude's CLAUDE.md (always use their latest configuration)
ln -sfv "$HOME/.dotfiles/claude/superclaude/CLAUDE.md" ~/.claude/CLAUDE.md

# symlink MCP servers config
ln -sfv "$HOME/.dotfiles/claude/mcp-servers.json" ~/.claude/mcp-servers.json

# setup OpenCode config
mkdir -p ~/.config/opencode
ln -sfv "$HOME/.dotfiles/opencode/config.json" ~/.config/opencode/config.json

# install rust toolchain
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# generate ssh-keygen
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -C "memorysaver"
fi

# change origin to push dotfiles
cd ~/.dotfiles
git remote set-url origin git@github.com:memorysaver/dotfiles.git

echo "Installation complete!"
