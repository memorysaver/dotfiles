#!/usr/bin/env bash

if [ ! -d "$HOME/.dotfiles" ]; then
  git clone https://github.com/memorysaver/dotfiles.git ~/.dotfiles
fi

# symlinks for dotfiles
ln -sfv "$HOME/.dotfiles/.spacemacs" ~
ln -sfv "$HOME/.dotfiles/.zshrc" ~
ln -sfv "$HOME/.dotfiles/git/.gitconfig" ~
ln -sfv "$HOME/.dotfiles/git/.gitmessage" ~

# generate ssh-keygen
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -C "memorysaver"
fi

# change origin to push dotfiles
cd ~/.dotfiles
git remote set-url origin git@github.com:memorysaver/dotfiles.git
