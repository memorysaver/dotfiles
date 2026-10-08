# Grok Bot sandbox computer

- 這台是 Cursor / Grok Bot 的 Debian 13 agent sandbox，不是 Omarchy 桌面，也別當成一般 Debian 工作站亂裝桌面件。
- Treat as a headless-ish Debian agent host. Do not install or configure Hyprland, Moonlight, mail (Himalaya/Ortie), or desktop apps unless the user explicitly asks.
- Use `just setup-grok-bot` for the tracked recipe: workspace → core → runtimes → agents → tools → seed-agents → grok-bot overlay → link → doctor.
- Packaging reuses Debian apt / upstream installer paths; the platform id is `grok-bot` so applied settings stay distinguishable from plain `setup-debian`.
- The grok-bot overlay also installs openssh-client, Tailscale, and QMD (grok-bot only), and wraps `pi` in Bun because the sandbox Node (20) is older than Pi needs (22.19). No systemd: start `tailscaled` by hand before `tailscale up`.
- Scheduled and event triggers come from Grok Bot routines (server-side saved prompts on cron or events). This recipe does not install Dagu, though it may exist on the host; it is not the scheduling entry point here. `just workspace-orchestrator` is not run here for now (it registers a Dagu DAG and user service units; there is no systemd).
- Keep repository work under `~/Work` when that layout is present; follow the common repository, idea-hub, and credential rules.
- Default binding: leave the sandbox unbound so `~/Work/orchestration-rules` stays on the public tree. The shared agent host is ephemeral and usually has no private `~/idea/private-config/computers/<id>/orchestration-rules` record. Bind with `just workspace-computer <id>` only when a private host entry with profile `grok-bot` exists.
