# Omarchy desktop computer

- Treat this as a user-facing graphical Omarchy session. Do not assume it is a headless server.
- Omarchy owns Hyprland and desktop application configuration. Prefer additive changes and preserve
  host-owned files, dynamic themes, existing keybindings, and user focus.
- Use `omarchy pkg add` for Omarchy packages and check existing configuration before editing.
- Claude Code, Codex, Pi, and Grok are Omarchy-managed Mise wrappers. Update them with
  `omarchy update` or `omarchy update mise`, not `claude update` / `codex update` /
  `pi update` / `grok update` or the vendor curl installers. Invoke grok via
  `~/.local/bin/grok`; do not put `~/.grok/bin` on PATH (Grok Build still writes its
  ELF there after a launch).
- Keep repository work under `~/Work`; use the common repository, idea-hub, and credential rules.
- For direct Herdr control, verify `HERDR_ENV=1` and use explicit IDs with `--no-focus`.
