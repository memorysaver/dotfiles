# Dotfiles Redesign — Simplify & Stabilize

## Objective

Redesign the dotfiles repo into a modular, idempotent, cross-platform (macOS + Linux) configuration system with categorized install segments and a single bootstrap entry point.

## Principles

1. **Idempotent** — every script is safe to re-run. Check before install, check before symlink.
2. **Single source of truth** — each tool's config lives in exactly one place.
3. **Cross-platform** — macOS (primary) and Linux (remote servers/sandboxes).
4. **Modular segments** — independently installable categories via `just`.

## Architecture

### Bootstrap Flow

```
bootstrap.sh (curl-able entry point)
  → Detect OS (macOS/Linux)
  → Install foundation (Homebrew or apt + git + zsh + just)
  → Clone dotfiles to ~/.dotfiles (if needed)
  → Run `just setup`
      → just core     (zsh, oh-my-zsh, tmux, starship, nvim, lazygit, git, direnv)
      → just runtimes (pyenv, uv, nvm, Node.js, Bun, Rust/Cargo)
      → just agents   (Claude Code, Codex, OpenCode, Pi)
      → just tools    (gh, glab, jq, yq, just, agent-browser, portless)
      → just link     (all symlinks + directory creation)
```

`just infra` (Terraform, Pulumi, SST) is opt-in, not part of default `setup`.

### Folder Structure

```
~/.dotfiles/
├── bootstrap.sh
├── justfile
├── lib/
│   └── helpers.sh               # ensure_installed, ensure_symlink, pkg_install, OS detect
├── install/
│   ├── core.sh
│   ├── runtimes.sh
│   ├── agents.sh
│   ├── tools.sh
│   └── infra.sh
├── config/
│   ├── zsh/
│   │   ├── .zshrc               # Slim (~80 lines)
│   │   └── dev-envs.sh          # tmux session helpers
│   ├── tmux/
│   │   └── .tmux.conf
│   ├── git/
│   │   ├── .gitconfig
│   │   └── .gitmessage
│   ├── starship/
│   │   └── starship.toml
│   ├── nvim/                    # Full LazyVim config (preserved)
│   └── lazygit/
│       └── config.yml
├── agents/
│   ├── claude/
│   │   ├── settings.json
│   │   ├── mcp-servers.json
│   │   ├── hooks/
│   │   │   └── cmux-notify.sh
│   │   ├── commands/
│   │   ├── output-styles/
│   │   └── statusline.sh
│   ├── codex/
│   │   └── config.toml
│   ├── opencode/
│   │   ├── opencode.json
│   │   └── oh-my-opencode.json
│   └── pi/
├── env/
│   ├── .env.example
│   └── .envrc
└── docs/
    └── plans/
```

### Symlink Map

| Source | Destination |
|--------|------------|
| config/zsh/.zshrc | ~/.zshrc |
| config/tmux/.tmux.conf | ~/.tmux.conf |
| config/git/.gitconfig | ~/.gitconfig |
| config/git/.gitmessage | ~/.gitmessage |
| config/nvim/ | ~/.config/nvim |
| config/starship/starship.toml | ~/.config/starship.toml |
| config/lazygit/config.yml | OS-dependent lazygit config path |
| agents/claude/settings.json | ~/.claude/settings.json |
| agents/claude/mcp-servers.json | ~/.claude/mcp-servers.json |
| agents/claude/hooks/* | ~/.claude/hooks/ |
| agents/claude/commands/* | ~/.claude/commands/ |
| agents/claude/output-styles/ | ~/.claude/output-styles |
| agents/claude/statusline.sh | ~/.claude/statusline.sh |
| agents/codex/config.toml | ~/.codex/config.toml |
| agents/opencode/*.json | ~/.config/opencode/ |
| env/.envrc | ~/.envrc |

## Key Decisions

### Terminal: cmux + tmux
- cmux as macOS terminal emulator (GPU-accelerated, agent notifications)
- tmux inside cmux for session management and detach/reattach
- tmux.conf includes `allow-passthrough on` for cmux notification escape sequences
- Linux: terminal-agnostic (headless servers), just tmux

### Notifications: cmux native
- Replace 5 Python hook scripts + 5 MP3 soundtracks with single `cmux-notify.sh`
- Uses `cmux notify` CLI (falls back to no-op if not in cmux)
- Hooks: Stop, PostToolUse (Task matcher)

### Secrets: direnv + .env files
- Global `~/.envrc` sources `~/.env` (gitignored)
- `.env.example` in repo as template
- Per-project `.envrc` can override
- Removes: 1Password CLI dependency, LiteLLM proxy, Claude Code Router

### Removed
- `.spacemacs` (nvim is primary editor)
- `.devcontainer/` and `dev-container/` (defer)
- `soundtrack/` (cmux notifications replace audio)
- `claude/hooks/*.py` (replaced by cmux-notify.sh)
- `claude/claude-code-router/` (replaced by env vars)
- `litellm/` (replaced by env vars)
- `scripts/` (redundant)
- `agent-deck/` (cmux replaces)
- `.gitmodules` (empty)

### Preserved as-is
- nvim/ config (full LazyVim setup)
- starship/starship.toml (gruvbox dark theme)
- lazygit/config.yml
- claude/output-styles/
- claude/statusline.sh
