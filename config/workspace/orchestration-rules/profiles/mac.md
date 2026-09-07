# macOS computer

- Use macOS-native paths and commands. Do not apply Omarchy or Linux package instructions.
- The normal shell and terminal configuration are managed through the dotfiles source.
- Use Homebrew or the dotfiles installation recipes for machine-wide tools.
- Keep ordinary project repositories under `~/Work` and follow the common repository rules.
  The private idea hub stays at `~/idea`, and public configuration stays at `~/.dotfiles`;
  these are canonical paths outside Work. Do not move them into Work to satisfy this profile.
  Route their work to their own repository workspaces using canonical paths.
- Treat GUI automation and application configuration as host-specific; inspect current state before
  changing it and preserve unrelated settings.
