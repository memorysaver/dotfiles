# dotfiles

Modular, idempotent dotfiles with explicit macOS, Omarchy, Arch, and
Debian-family installation paths, orchestrated with `just`.

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
| `just core` | platform shell, tmux, starship, nvim, lazygit, git-lfs, direnv |
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
│   ├── omarchy-apps.sh
│   ├── omarchy-moonlight.sh
│   └── infra.sh
├── config/               # App configs (symlinked to ~)
│   ├── zsh/
│   ├── tmux/
│   ├── git/
│   ├── starship/
│   ├── nvim/
│   ├── lazygit/
│   ├── workspace/             # ~/Work navigation policy
│   └── hypr/                 # Additive Omarchy/Moonlight module
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
just setup             # Detect platform; install tools and seed new agent configs
just setup-macos       # Require macOS, then install the shared tool set
just setup-omarchy     # Require Omarchy; use Omarchy packages + Mise
just omarchy-apps      # Install the personal Omarchy desktop app set
just omarchy-moonlight # Set Moonlight system-shortcut capture to Always
just omarchy-sunshine-headless # Opt in to a 16:10 virtual Sunshine display
just setup-arch        # Require Arch; use pacman + Mise
just setup-debian      # Require Debian/Ubuntu; use apt and upstream installers
just link              # Create all config symlinks (idempotent)
just link-dry-run      # Show creates/conflicts without writing anything
just unlink            # Remove all symlinks
just seed-agents       # Copy agent config templates to ~ (never overwrites)
just doctor            # Health-check this machine (read-only, exits 1 on failure)
just check-agent-links # Warn if any agent config still links back into this repo
just infra             # Install infrastructure tools (opt-in)
just --list            # Show all available recipes
```

`just setup` detects the platform and dispatches to one of the explicit setup
recipes. Tool installation and config linking are separate: setup never replaces
working configuration as a side effect. Run `just link-dry-run` first. Linking
refuses existing paths by default; `DOTFILES_LINK_MODE=backup just link` moves
each conflict to a timestamped backup before creating its symlink.

`just setup-omarchy` asks for sudo authentication once at the beginning,
installs tools and applications, and activates the safe Bash overlay. Subsequent
package operations reuse that authorization. Run it from a terminal so the
password prompt is visible.

On Omarchy, the repository installs and verifies command-line tools but preserves
Omarchy's application configuration. Git, tmux, Starship, Lazygit, Neovim,
Herdr, terminals, and Omarchy Shell remain machine-local and follow Omarchy
defaults. Hyprland also remains host-owned: the only exception is one additive
Moonlight module, linked below `~/.config/hypr/remote_desktop.lua` and enabled by
one exact `require("hypr.remote_desktop")` line in the existing
`~/.config/hypr/bindings.lua`. No stock binding file is replaced.

## Terminal configuration by platform

macOS uses Zsh + Oh My Zsh and the tracked Ghostty profile. Omarchy stays on
Bash: `just link` adds one source line to the existing Omarchy `~/.bashrc`, which
loads shared personal aliases, environment, and browser helpers after Omarchy's
own Mise, Starship, Zoxide, FZF, completion, editor, and browser setup.

```text
config/shell/common/                 # Bash/Zsh-compatible personal additions
config/shell/omarchy/dotfiles.bash   # Additive Omarchy Bash adapter
config/zsh/                          # macOS Zsh + Oh My Zsh entrypoints
config/starship/macos.toml           # macOS-only powerline prompt
config/terminal/macos/ghostty.conf   # macOS Ghostty and CJK font chain
config/terminal/omarchy/README.md    # Omarchy configuration ownership policy
config/hypr/remote_desktop.lua       # Additive Moonlight remote-desktop mode
config/hypr/sunshine_headless.lua    # Opt-in headless Sunshine host display
config/lazygit/config.yml            # macOS and non-Omarchy Linux only
config/tmux/.tmux.conf               # macOS and non-Omarchy Linux only
```

On Omarchy, `just link` does not replace any application configuration. It
adds only the repository module and its `require` line, keeping dynamic themes,
existing keybindings, and future Omarchy migrations intact. The first change to
an existing host file gets a timestamped `.pre-dotfiles.<timestamp>` backup.

## Omarchy + Moonlight remote desktop

`just setup-omarchy` installs `moonlight-qt`, sets Moonlight's
`capturesyskeys=2` preference (the app's **Always** mode), and links the
additive Hyprland module. The Moonlight preference script edits only that one
key; it never stores or replaces host names, pairing keys, or other private
settings. If Moonlight is open, the script skips the edit so QSettings cannot
race the installer; close it and rerun `just omarchy-moonlight`.

The module uses the current Omarchy Lua configuration API:

1. Focus the Moonlight stream and press **Super+F12**. A notification says
   `Remote Desktop Mode ON`.
2. While enabled, normal local Hyprland bindings are inactive, so Super,
   Alt+Tab, and similar shortcuts can reach the Sunshine host.
3. Press **Super+F12** again to reset the submap. A notification says
   `Remote Desktop Mode OFF`, and local Super bindings work again.

For a manually configured machine, set Moonlight's **Capture system keyboard
shortcuts** preference to **Always** once in its settings. Validate a change
with:

```bash
hyprctl reload
hyprctl configerrors
hyprctl submap
```

`hyprctl configerrors` should be empty and `hyprctl submap` should report
`default` outside the mode. `just link-dry-run` shows the module, source-line,
and any conflict before writing. `just unlink` removes only the repository
symlink and exact `require` line; all timestamped backups remain available.

For an Omarchy machine that runs Sunshine without a physical monitor, run
`just omarchy-sunshine-headless`, then log out and back in. This opt-in task
installs an isolated Hyprland module and adds one exact require line to the
host-owned `autostart.lua`. The module creates `HEADLESS-1` at 1920x1200@60
with scale 1.25 for MacBook clients; it is intentionally excluded from the
normal workstation setup. Keep Moonlight's experimental YUV 4:4:4 option off:
it caused remote pointer coordinate drift in this headless configuration.
The module is a managed real file rather than a symlink because Hyprland's
sandboxed Lua loader cannot require a target outside `~/.config/hypr`.

## Tailnet SSH access policy

Remote access to the Omarchy workstation runs over Tailscale, and two SSH
services own different ports:

| Port | Service | Host key |
| --- | --- | --- |
| 22 | Tailscale SSH, served by `tailscaled` in netstack | Generated and held by `tailscaled` |
| 2222 | OpenSSH, key-only, reachable on `tailscale0` | The machine's `/etc/ssh` host keys |

`herdr --remote <host>` and a plain `ssh <host>` both use port 22, so they are
answered by Tailscale SSH rather than OpenSSH. That is why
`just audit-remote-access` reports a kernel listener on TCP 22 as a soft note,
and why the host key on port 22 can appear to change without the machine being
compromised: reinstalling the workstation or re-enabling Tailscale SSH replaces
the key that port presents, and OpenSSH's host key on 2222 is unrelated to it.

When `REMOTE HOST IDENTIFICATION HAS CHANGED` appears for port 22, rescan the
key and confirm the fingerprint matches the one quoted in the warning before
trusting it:

```bash
ssh-keyscan -t ed25519 <host> | ssh-keygen -lf -   # compare with the warning
ssh-keygen -R <host>                               # drop the stale entry
```

An `SSH-2.0-Tailscale` banner in the `ssh-keyscan` output confirms the key
belongs to Tailscale SSH.

The tailnet policy file is cloud-managed and cannot live in this repository, so
the intended `ssh` block is recorded here (set 2026-08-30):

```json
"ssh": [
    {
        "action": "accept",
        "src":    ["autogroup:member"],
        "dst":    ["autogroup:self"],
        "users":  ["autogroup:nonroot"],
    },
],
```

Two deliberate departures from Tailscale's default block:

- `accept` rather than `check`. Check mode forces a browser re-authentication on
  the connecting client, and its 12-hour default interrupts long Herdr sessions.
  A custom `checkPeriod` would soften that, but it is a Premium/Enterprise
  feature: saving one on a Free tailnet fails with `Functionality outside your
  plan`. The real choice is every 12 hours or never.
- `autogroup:nonroot` with `root` removed. This matches the `permitrootlogin no`
  baseline the audit already enforces for OpenSSH — log in as the workstation
  user and `sudo` on the box. Left in place, `accept` would allow passwordless
  root logins from every device in the tailnet.

Dropping check mode does not make device access permanent. Node keys still
expire roughly every 180 days, at which point that device re-authenticates to
Tailscale itself; that is a device-level event, unrelated to per-connection SSH
checks. Revocation stays central too: removing a device in the admin console
cuts its access to every node at once, with no `authorized_keys` edits.

## Omarchy tool ownership

`just setup-omarchy` ensures the workstation tools are installed; it does not
adopt their configuration. The main groups are:

| Group | Installed or verified |
| --- | --- |
| Terminal/core | tmux, Starship, Neovim, Lazygit, Git LFS, direnv |
| Development runtimes | Mise; Omarchy's `node@latest`; personal Python, uv, Bun, and Rust additions |
| CLI utilities | GitHub CLI, GitLab CLI, jq, yq, just, agent-browser, portless |
| Coding agents | Herdr, Claude Code, Codex, OpenCode, Antigravity, Grok, Pi |

Omarchy-supported command-line agents are installed with
`omarchy-mise-install`, matching Omarchy's own installer design. This creates
small commands in `~/.local/bin` that resolve and execute the tool through Mise:

| Mise-managed on Omarchy | Installation spec |
| --- | --- |
| GitHub CLI | `gh` |
| Claude Code | `claude` |
| Codex CLI | `codex` |
| OpenCode | `opencode` |
| Grok | `npm:@xai-official/grok` |
| Pi | `pi` |
| agent-browser, portless | Personal npm tools, also wrapped through Mise |

On Omarchy, `agent-browser` defaults to the existing `mfa` Chromium profile;
agent-browser clones it into a temporary user-data directory, so the everyday
browser can remain open. Use `--profile Work` or `ab-profile Work [url]` to
switch profiles. `ab-isolated [name] [url]` starts without personal cookies,
while `ab-connect [name] [port]` retains the older persistent isolated CDP
profile under `~/.chrome-cdp/`. Profile-backed sessions expose that profile's
cookies and cannot use agent-browser's `--allowed-domains` containment.

Herdr is an Omarchy system package rather than a Mise tool. Omarchy installs it
as `/usr/bin/herdr`, seeds `~/.config/herdr/config.toml`, and upgrades it through
`omarchy update`; `omarchy refresh herdr` explicitly restores Omarchy's shipped
configuration. Antigravity (`agy`) is the remaining personal addition not
supplied by Omarchy, so it retains its official installation route. macOS also
retains the existing Homebrew/vendor routes; this ownership rule is specific to
Omarchy.

Other declared Omarchy tools follow their native owner as well:

| Owner | Dotfiles selections |
| --- | --- |
| Omarchy base packages | Chromium, Obsidian, Git, jq, Lazygit, Neovim, Starship, tmux, Herdr |
| Arch packages through `omarchy pkg add` | Git LFS, direnv, glab, yq, just, Terraform, Pulumi |
| Omarchy service/setup commands | 1Password and Voxtype |
| Omarchy Mise wrappers | gh and the supported coding agents listed above |
| Personal additions | `agy`, SST, agent-browser, portless, and global agent skills |

Desktop applications already supplied by Omarchy remain Omarchy's
responsibility. Platform-specific additions belong in the Omarchy installation
path, never in macOS configuration-linking logic. Run `just doctor` to report
missing commands and which configuration is intentionally Omarchy-managed.

## Omarchy workstation recovery

On a fresh Omarchy laptop, run the bootstrap command from a terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/memorysaver/dotfiles/main/bootstrap.sh)"
```

The Omarchy path performs the following recovery steps:

1. Installs the shared CLI tools, development runtimes, and coding agents.
2. Ensures the personal desktop application set is installed.
3. Configures Moonlight's non-secret keyboard-capture preference and links the
   additive Hyprland remote-desktop module without replacing Omarchy defaults.
4. Adds the portable aliases, paths, and functions to Omarchy's existing Bash
   setup without replacing its defaults.
5. Leaves every other application configuration under Omarchy ownership.
6. Runs `just doctor` as a final gate; bootstrap does not report success while a
   declared command, application, skill, or shell link is missing.

The explicit application set is:

| Application | Installation route | Configuration ownership |
| --- | --- | --- |
| 1Password + `op` CLI | `omarchy install service 1password` | Machine-local; sign in interactively |
| Tailscale | `omarchy install service tailscale` | Omarchy service/bar integration; authenticate interactively |
| btop | `omarchy pkg add btop` | Omarchy |
| Chromium | `omarchy pkg add chromium` | Omarchy |
| Moonlight | `omarchy pkg add moonlight-qt` | Module in this repo; hosts and pairing remain local |
| Obsidian | `omarchy pkg add obsidian` | Machine-local vault and settings |
| Voxtype | `omarchy voxtype install` | Omarchy setup; machine-local model and settings |

Chromium and Obsidian are normally Omarchy preinstalls, but they are listed
explicitly so a restored workstation does not depend on a particular Omarchy
release's default app selection. Installation is idempotent; already-installed
packages are left in place. Authentication, vault data, and downloaded Voxtype
models are intentionally not stored in this repository.

## Agent Configs Are Machine-Local

Portable entries under `config/` are symlinked into `~` — one source of truth
across machines. Omarchy-managed application configs are intentionally excluded
on Omarchy. Everything under `agents/` is **not**. Claude Code, Codex, Pi and OpenCode
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

The build itself runs `verify.sh`, which checks the Debian/macOS-style config
links, seeded agent configs, global skills, and installed commands. Platform
smoke tests separately cover the Omarchy shell overlay and ownership boundary.

## Key Tools

- **Shell**: Zsh + Oh My Zsh on macOS; Omarchy Bash with a personal overlay
- **Editor**: Neovim (LazyVim)
- **Git**: Lazygit TUI + gh/glab CLIs; configuration follows the host platform
- **Terminal**: macOS uses the tracked tmux theme; Omarchy keeps its defaults
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
