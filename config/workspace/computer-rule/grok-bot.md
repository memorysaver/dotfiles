# Grok Bot sandbox computer

- 這台是 Cursor / Grok Bot 的 Debian 13 agent sandbox，不是 Omarchy 桌面，也別當成一般 Debian 工作站亂裝桌面件。
- Treat as a headless-ish Debian agent host. Do not install or configure Hyprland, Moonlight, mail (Himalaya/Ortie), or desktop apps unless the user explicitly asks.
- Use `just setup-grok-bot` for the tracked recipe: workspace → core → runtimes → agents → tools → seed-agents → grok-bot overlay → link → doctor.
- Packaging reuses Debian apt / upstream installer paths; the platform id is `grok-bot` so applied settings stay distinguishable from plain `setup-debian`.
- Keep repository work under `~/Work` when that layout is present; follow the common repository and credential rules.
