# dotfiles

Modular, idempotent, cross-platform dotfiles with `just` orchestration.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/bootstrap.sh | bash
```

Or manually:

```bash
git clone https://github.com/memorysaver/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
just setup
```

## What's Included

| Recipe | Tools |
|--------|-------|
| `just core` | zsh, oh-my-zsh, tmux, starship, nvim, lazygit, direnv |
| `just runtimes` | pyenv, uv, nvm, Node.js, Bun, Rust |
| `just agents` | Claude Code, Codex CLI, OpenCode, Pi |
| `just tools` | gh, glab, jq, yq, just, agent-browser, portless |
| `just infra` | Terraform, Pulumi, SST *(opt-in, not in default setup)* |

## Folder Structure

```
~/.dotfiles/
├── bootstrap.sh          # One-command entry point
├── justfile              # Task runner (just setup, just link, etc.)
├── lib/helpers.sh        # Shared idempotent utilities
├── install/              # Categorized install scripts
│   ├── core.sh
│   ├── runtimes.sh
│   ├── agents.sh
│   ├── tools.sh
│   └── infra.sh
├── config/               # App configs (symlinked to ~)
│   ├── zsh/
│   ├── tmux/
│   ├── git/
│   ├── starship/
│   ├── nvim/
│   └── lazygit/
├── agents/               # AI tool configs (symlinked to ~)
│   ├── claude/
│   ├── codex/
│   ├── opencode/
│   └── pi/
└── env/                  # Environment config
    ├── .env.example
    └── .envrc
```

## Just Recipes

```bash
just setup    # Full setup: core + runtimes + agents + tools + link
just link     # Create all config symlinks (idempotent)
just unlink   # Remove all symlinks
just infra    # Install infrastructure tools (opt-in)
just --list   # Show all available recipes
```

## Environment Variables

```bash
cp ~/.dotfiles/env/.env.example ~/.env
# Fill in your API keys, then:
direnv allow ~
```

Keys loaded automatically via direnv when you open a shell.

## Docker Dev Sandbox

Test the full setup in an isolated Linux container without touching your host machine.

```bash
# Build the image (runs all install scripts + verifies symlinks/commands)
bash docker/docker-test.sh

# Build and drop into a zsh shell
bash docker/docker-test.sh --run

# Force a clean rebuild (no cache)
bash docker/docker-test.sh --no-cache

# Launch a shell into an existing image
docker run --rm -it memorysaver-dev

# Run in background and attach multiple shells
docker run -d --name dev memorysaver-dev sleep infinity
docker exec -it dev zsh
docker stop dev && docker rm dev
```

The build itself runs `verify.sh` which checks all 15 symlinks and 20 commands — if anything is broken, the build fails.

## Key Tools

- **Shell**: zsh + oh-my-zsh + starship prompt
- **Editor**: Neovim (LazyVim)
- **Git**: lazygit TUI + gh/glab CLIs
- **Terminal**: tmux with Tokyo Night theme
- **AI Agents**: Claude Code, Codex, OpenCode, Pi
- **Dev Envs**: `ccdev`, `opendev`, `codexdev` — tmux sessions with lazygit + AI agent

## License

MIT
