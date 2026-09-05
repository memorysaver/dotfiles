# Omarchy desktop computer

- Treat this as a user-facing graphical Omarchy session. Do not assume it is a headless server.
- Omarchy owns Hyprland and desktop application configuration. Prefer additive changes and preserve
  host-owned files, dynamic themes, existing keybindings, and user focus.
- Use `omarchy pkg add` for Omarchy packages and check existing configuration before editing.
- Keep repository work under `~/Work`; use the common repository, idea-hub, and credential rules.
- For direct Herdr control, verify `HERDR_ENV=1` and use explicit IDs with `--no-focus`.
- When acting as host-native OpenAB, read `openab-orchestrator.md` before dispatching work.
