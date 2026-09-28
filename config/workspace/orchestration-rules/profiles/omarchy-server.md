# Omarchy server computer

- Treat this as a server workstation. A graphical or virtual session may exist; inspect capabilities
  when needed rather than assuming a display, browser, or local interactive focus.
- Prefer systemd user services, terminal commands, Tailscale SSH and Herdr remote workflows.
- Do not launch GUI applications or alter desktop configuration unless the user explicitly requests
  that host role to provide a graphical session.
- Keep repository work under `~/Work` and follow the common repository, idea-hub, and credential rules.
- Claude Code, Codex, Pi, and Grok are Omarchy-managed Mise wrappers. Update them with
  `omarchy update` or `omarchy update mise`, not `claude update` / `codex update` /
  `pi update` / `grok update` or the vendor curl installers. Invoke grok via
  `~/.local/bin/grok`; do not put `~/.grok/bin` on PATH (Grok Build still writes its
  ELF there after a launch).
- If a task needs a graphical capability, inspect whether this host provides it. If unavailable,
  report the limitation; do not implicitly dispatch to another computer.
