# Omarchy configuration ownership

Omarchy owns its active application configuration. This dotfiles repository
installs and checks tools, but does not symlink over Git, tmux, Starship,
Lazygit, Neovim, Herdr, Hyprland, Omarchy Shell, Foot, or Ghostty configuration.

The stock files intentionally include dynamic theme output from:

```text
~/.local/state/omarchy/current/theme/foot.ini
~/.local/state/omarchy/current/theme/ghostty.conf
```

Changes to those applications should be made through Omarchy or in their local
user configuration. The only repository-managed Omarchy integration is an
optional additive Bash fragment for personal aliases, paths, and functions.
