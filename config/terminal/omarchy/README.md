# Omarchy terminal ownership

Omarchy owns the active terminal configuration. This dotfiles repository does
not symlink over `~/.config/foot/foot.ini` or `~/.config/ghostty/config`.

The stock files intentionally include dynamic theme output from:

```text
~/.local/state/omarchy/current/theme/foot.ini
~/.local/state/omarchy/current/theme/ghostty.conf
```

Personal terminal changes should be applied as small Omarchy-safe overlays and
must retain those includes. The current default terminal is selected through
Omarchy, not through this repository.
