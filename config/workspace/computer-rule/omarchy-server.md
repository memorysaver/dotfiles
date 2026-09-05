# Omarchy server computer

- Treat this as a headless or remote-only host. Do not assume a display, Wayland, Hyprland, browser,
  or local interactive focus exists.
- Prefer systemd user services, terminal commands, Tailscale, SSH, Moshi, and Herdr remote workflows.
- Do not launch GUI applications or alter desktop configuration unless the user explicitly requests
  that host role to provide a graphical session.
- Keep repository work under `~/Work` and follow the common repository, idea-hub, and credential rules.
- If a task requires a graphical desktop, identify the desktop host and propose dispatching there.
