#!/usr/bin/env bash

if [ ! -d "$HOME/.dotfiles" ]; then
  git clone git://github.com/memorysaver/dotfiles.git ~/.dotfiles
fi

# generate ssh-keygen
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -C "mfa1484@gmail.com"
fi

# symlinks for dotfiles
ln -sfv "$HOME/.dotfiles/.spacemacs" ~
ln -sfv "$HOME/.dotfiles/.zshrc" ~
ln -sfv "$HOME/.dotfiles/git/.gitconfig" ~
ln -sfv "$HOME/.dotfiles/git/.gitmessage" ~

# change origin to push dotfiles
cd ~/.dotfiles
git remote set-url origin git@github.com:memorysaver/dotfiles.git
