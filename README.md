# dotfiles

Modular, idempotent, cross-platform dotfiles with `just` orchestration.

## Quick Start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/bootstrap.sh)"
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
| `just agents` | Herdr, global skills (`herdr`, `i-have-adhd`, `agent-browser`), Claude Code, Codex CLI, OpenCode, Antigravity CLI (agy), Grok Build, Pi |
| `just tools` | gh, glab, jq, yq, just, agent-browser, portless, mole (macOS only) |
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
├── agents/               # AI tool config templates (copied to ~, never symlinked)
│   ├── claude/
│   ├── codex/
│   ├── opencode/
│   ├── pi/
│   └── skills/           # Skill source, installed per project by the skills CLI
└── env/                  # Environment config
    ├── .env.example
    └── .envrc.template
```

## Just Recipes

```bash
just setup             # Full setup: core + runtimes + agents + tools + link + seed-agents
just link              # Create all config symlinks (idempotent)
just unlink            # Remove all symlinks
just seed-agents       # Copy agent config templates to ~ (never overwrites)
just doctor            # Health-check this machine (read-only, exits 1 on failure)
just check-agent-links # Warn if any agent config still links back into this repo
just infra             # Install infrastructure tools (opt-in)
just --list            # Show all available recipes
```

## Agent Configs Are Machine-Local

Everything under `config/` is symlinked into `~` — one source of truth across
machines. Everything under `agents/` is **not**. Claude Code, Codex, Pi and OpenCode
each rewrite their own config in place (trusted paths, plugin state, sandbox mode,
app internals), and their formats change faster than a shared repo can usefully
track. A symlink turned every one of those writes into an uncommitted diff here.

So `agents/*/` holds **templates**, not live config:

```bash
just seed-agents        # fresh machine: copy templates into ~, skip anything present
just adopt-agents       # old machine: turn existing symlinks into real files
just check-agent-links  # audit: nothing under ~/.claude, ~/.codex, ~/.pi should link here
```

After seeding, each machine owns its copy. Edit `~/.claude/settings.json` directly;
this repo will not touch it again. Update a template here only when you want a
*new* machine to start from something different.

### Migrating a machine set up before 2026-07-30

`just seed-agents` **will not** fix an already-linked machine — a symlink counts as
"already exists", so every path gets skipped and stays linked to this repo. Run this
once on each old machine instead:

```bash
cd ~/.dotfiles && git pull
just adopt-agents       # dereferences each link in place, keeping content and mode
just check-agent-links  # should report nothing
```

`adopt-agents` copies through the link before removing it, so your live settings —
including anything the app wrote that was never committed here — survive intact.
File modes are preserved (`statusline.sh` stays executable, `~/.codex/config.toml`
stays `0600`). Links owned by something else, such as the skill links the skills CLI
installs into `~/.claude/skills`, are reported but never touched. Both recipes are
idempotent.

Links under `~/.claude/skills`, `~/.codex/skills` and `~/.pi/agent/skills` **that point
into this repo** are the one exception: those are deleted, not dereferenced. Skills moved
to per-project installs in the same migration, so dereferencing would rebuild the global
skill tree as real directories — one duplicate copy per agent — which is exactly what that
change removed. The `herdr`, `i-have-adhd` and `agent-browser` links that `just agents`
installs in those same directories point at `~/.agents/skills`, not here, so they fall
under the never-touched rule above and survive. Reinstall what a project needs with
`npx skills add memorysaver/dotfiles`; see
[docs/agent-skills-sources.md](docs/agent-skills-sources.md) for where each one now lives.

## Environment Variables

direnv uses per-project `.envrc` files. A template is provided:

```bash
# Copy the template into any project
cp ~/.dotfiles/env/.envrc.template ~/my-project/.envrc
# Customize it, then allow:
cd ~/my-project && direnv allow
```

For API keys, copy the example env file into your project and use `dotenv_if_exists` in your `.envrc`:

```bash
cp ~/.dotfiles/env/.env.example ~/my-project/.env
```

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

The build itself runs `verify.sh` which checks the 8 config symlinks, the 8 seeded agent configs plus the 3 global skills (asserting they are real files, not links), and 22 commands — if anything is broken, the build fails.

## Key Tools

- **Shell**: zsh + oh-my-zsh + starship prompt
- **Editor**: Neovim (LazyVim)
- **Git**: lazygit TUI + gh/glab CLIs
- **Terminal**: tmux with Tokyo Night theme; Herdr as the agent multiplexer
- **AI Agents**: Claude Code, Codex, OpenCode, Antigravity CLI (`agy`), Grok Build (`grok`), Pi
- **Shared Skills**: authored once under `agents/skills/`, installed per project via the skills CLI
- **Dev Envs**: `ccdev`, `opendev`, `codexdev` — tmux sessions with lazygit + AI agent

## Shared Skill Portability

Shared skills live under `agents/skills/<skill-name>/` and are the single source of
truth. They are **not installed globally** — as of 2026-07-28 nothing is symlinked into
`~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or the Antigravity CLI's
skill directory. The exceptions are `herdr`, `i-have-adhd` and `agent-browser`, installed globally by
`just agents`. The first two stay inert until deliberately activated; `agent-browser` is a
deliberate override that does not. `docs/agent-skills-sources.md` states the bar in full.
Install everything else per project, from this public repo:

```bash
npx skills@1.5.20 add memorysaver/dotfiles --skill <name> -a claude-code -a codex -a pi -y
```

Each agent has its own project-level skill directory, so let the CLI pick the target:

| Agent | Project skill directory |
| --- | --- |
| Claude Code | `<project>/.claude/skills` |
| Codex | `<project>/.agents/skills` |
| Pi | `<project>/.pi/skills` |
| Antigravity CLI (`agy`) | `<project>/.agents/skills` |

See `docs/agent-skills-sources.md` for every other skill source and the
`skills-lock.json` format, and `docs/removed-agent-clis.md` for the skill-installer
and skill-backend CLIs this repo used to install globally (and how to get them back).

Use `just validate-skills` to verify that every shared skill:

- has required frontmatter
- uses a directory name that matches the skill name
- only references files that actually exist
- avoids harness-specific paths in the shared core

## Codex Config Template

`agents/codex/config.toml` is a **template**, not your live config. The Codex CLI
and desktop app continuously write machine-local state into `~/.codex/config.toml`
— trusted project paths, plugin/runtime state, sandbox mode, Codex.app internals.
While that file was symlinked here, the only way to keep private project names out
of this public repo was to pin it with `skip-worktree`, which meant `git status`
lied about it by design. De-linking removes both problems: the live file is yours,
the template is plain tracked content.

The template deliberately stays minimal and safe:

- `sandbox_mode = "workspace-write"` (not `danger-full-access`)
- `model = "gpt-5.6-sol"`
- no local `[projects.*]` trust entries beyond the repo itself

Edit it like any other file. Nothing is pinned — `git ls-files -v agents/` should
show no `S` flags. When you change it, you are changing what the *next* machine
starts with; run `just seed-agents` there, or copy it by hand onto a machine you
want to reset.

### Global Codex instructions

`agents/codex/AGENTS.md` is the template for `~/.codex/AGENTS.md`, the machine-wide
Codex instructions (project-level `AGENTS.md` files still win).

**Known tradeoff:** third-party installers write into `~/.codex/AGENTS.md` without
asking — one (`mgrep`) once overwrote the whole file with an "always use this, never
use grep" directive. The symlink used to surface that in `git diff` for free. It no
longer does. If a global agent instruction file starts behaving oddly, diff it against
the template by hand:

```bash
diff ~/.codex/AGENTS.md ~/.dotfiles/agents/codex/AGENTS.md
diff ~/.claude/settings.json ~/.dotfiles/agents/claude/settings.json
```

## License

MIT
