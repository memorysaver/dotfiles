#!/usr/bin/env bash

if [ ! -d "$HOME/.dotfiles" ]; then
  git clone https://github.com/memorysaver/dotfiles.git ~/.dotfiles
fi

# symlinks for dotfiles
ln -sfv "$HOME/.dotfiles/.spacemacs" ~
ln -sfv "$HOME/.dotfiles/.zshrc" ~
ln -sfv "$HOME/.dotfiles/git/.gitconfig" ~
ln -sfv "$HOME/.dotfiles/git/.gitmessage" ~
ln -sfv "$HOME/.dotfiles/nvim" ~/.config/nvim

# setup claude commands directory and symlinks
mkdir -p ~/.claude/commands
for file in "$HOME/.dotfiles/claude/commands"/*; do
  if [ -f "$file" ]; then
    ln -sfv "$file" ~/.claude/commands/
  fi
done

# setup claude global development rules
ln -sfv "$HOME/.dotfiles/claude/CLAUDE.md" ~/.claude/CLAUDE.md

# generate ssh-keygen
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -C "memorysaver"
fi

# change origin to push dotfiles
cd ~/.dotfiles
git remote set-url origin git@github.com:memorysaver/dotfiles.git
