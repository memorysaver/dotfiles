# Computer rules

These files are supplemental machine and host-role guidance for `~/Work`. Keep repository
instructions in the nearest `AGENTS.md`; keep universal workspace policy in the parent `AGENTS.md`.
Read only the profile that matches the current machine.

## Profiles

- `mac.md`: macOS workstation.
- `omarchy-desktop.md`: user-facing graphical Omarchy desktop.
- `omarchy-server.md`: headless or remote Omarchy host.
- `openab-orchestrator.md`: only when operating the host-native `openab-omarchy` orchestrator.

Choose the profile from the actual environment: `uname -s` identifies macOS; an Omarchy host has
`/etc/omarchy-release`; a graphical user session is a desktop, while a headless or remote-only host
is a server. If the role is ambiguous, ask before making machine-specific changes.

The source of these rules is `~/.dotfiles/config/workspace/computer-rule/`. The deployed directory
`~/Work/computer-rule` is managed by the dotfiles workspace setup.
