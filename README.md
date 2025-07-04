# dotfiles
[![Built with Spacemacs](https://cdn.rawgit.com/syl20bnr/spacemacs/442d025779da2f62fc86c2082703697714db6514/assets/spacemacs-badge.svg)](http://spacemacs.org)

## Installation Guide
### Run Installation scrips

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
```

**Key Features:**
- Prefix key: `Ctrl+a` (instead of `Ctrl+b`)
- Split panes: `Ctrl+a |` (horizontal) and `Ctrl+a -` (vertical)
- Navigate panes: `Alt+arrows` or `Ctrl+a hjkl`
- Reload config: `Ctrl+a r`
- Mouse support enabled
- Tokyo Night color scheme

### Claude Code Development Environment

The `ccdev` function creates a tmux development environment optimized for Claude Code:

```bash
# Launch development environment
ccdev [session-name]

# If no session name provided, uses current directory name
ccdev my-project
```

Creates a multi-pane workspace with Neovim, development server, Claude Code CLI, and Lazygit automatically configured and ready to use.
