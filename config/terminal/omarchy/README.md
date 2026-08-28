# Omarchy configuration ownership

Omarchy owns its active application configuration. This dotfiles repository
installs and checks tools, but does not symlink over Git, tmux, Starship,
Lazygit, Neovim, Herdr, Omarchy Shell, Foot, or Ghostty configuration.

Hyprland remains host-owned as well, with one deliberate additive exception:
`config/hypr/remote_desktop.lua` is linked to
`~/.config/hypr/remote_desktop.lua`, and `just link` appends the exact
`require("hypr.remote_desktop")` line to the existing
`~/.config/hypr/bindings.lua`. No default bindings or user modules are
replaced. The link refuses an existing module path unless the user explicitly
chooses `DOTFILES_LINK_MODE=backup`.

The stock files intentionally include dynamic theme output from:

```text
~/.local/state/omarchy/current/theme/foot.ini
~/.local/state/omarchy/current/theme/ghostty.conf
```

Changes to those applications should be made through Omarchy or in their local
user configuration. The repository-managed Omarchy integrations are the
optional additive Bash fragment for personal aliases, paths, and functions,
plus the opt-in Moonlight remote-desktop module. `just omarchy-moonlight`
updates only Moonlight's non-secret `capturesyskeys` preference and creates a
timestamped backup before changing an existing config.
