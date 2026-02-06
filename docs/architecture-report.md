# Dotfiles Cross-Platform Architecture Report

## 1. Current State Analysis

### Directory Structure (as-is)

```
~/.dotfiles/
├── .devcontainer/          # Docker-based dev environment (Linux container)
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── init-firewall.sh
│   └── README.md
├── .github/workflows/      # CI/CD
│   ├── claude-code-review.yml
│   └── claude.yml
├── agent-deck/             # Agent-deck TUI config
│   └── config.toml
├── claude/                 # Claude Code ecosystem
│   ├── CLAUDE.md
│   ├── claude-code-router/
│   │   ├── .env
│   │   └── config.json
│   ├── commands/           # (empty or minimal)
│   ├── hooks/
│   │   ├── session_start.py
│   │   ├── notification.py
│   │   ├── pre_tool_use.py
│   │   ├── user_prompt_submit.py
│   │   └── stop.py
│   ├── output-styles/
│   │   └── cloudflare-workers-monorepo-maintainer.md
│   ├── mcp-servers.json
│   ├── settings.json
│   └── statusline.sh
├── dev-container/          # Empty directory (orphan?)
├── git/
│   ├── .gitconfig
│   └── .gitmessage
├── lazygit/
│   └── config.yml
├── litellm/
│   ├── .env.template
│   ├── config.yaml
│   └── README.md
├── nvim/                   # Full LazyVim config (LazyVim starter)
│   ├── init.lua
│   ├── lua/config/
│   ├── lua/plugins/
│   ├── lazy-lock.json
│   └── ...
├── openai-codex/
│   └── config.toml
├── opencode/
│   ├── opencode.json
│   └── oh-my-opencode.json
├── scripts/
│   ├── setup-mcp.sh
│   └── sync-codex-config.py
├── soundtrack/             # Sound effects for hooks
│   ├── work-work.mp3
│   ├── work-complete.mp3
│   ├── battle-cruiser-operational.mp3
│   ├── Jinx-Everybody-Panic.mp3
│   └── Teemo-On-Duty.mp3
├── .gitignore
├── .gitmodules             # Empty (submodule removed)
├── .spacemacs              # Legacy Emacs config
├── .tmux.conf
├── .zshrc
├── install.sh
├── LICENSE
└── README.md
```

### How Configs Are Currently Organized and Symlinked

The `install.sh` script is the primary installation mechanism. It creates symlinks from `~/.dotfiles/` to their expected locations:

| Source in dotfiles | Target on system | Method |
|---|---|---|
| `.spacemacs` | `~/.spacemacs` | Direct symlink |
| `.zshrc` | `~/.zshrc` | Direct symlink |
| `.tmux.conf` | `~/.tmux.conf` | Direct symlink |
| `git/.gitconfig` | `~/.gitconfig` | Direct symlink |
| `git/.gitmessage` | `~/.gitmessage` | Direct symlink |
| `nvim/` | `~/.config/nvim` | Directory symlink |
| `lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` | Direct symlink (macOS-specific!) |
| `claude/commands/*` | `~/.claude/commands/` | Per-file symlinks |
| `claude/mcp-servers.json` | `~/.claude/mcp-servers.json` | Direct symlink |
| `claude/settings.json` | `~/.claude/settings.json` | Direct symlink |
| `claude/statusline.sh` | `~/.claude/statusline.sh` | Direct symlink |
| `opencode/opencode.json` | `~/.config/opencode/opencode.json` | Direct symlink |
| `opencode/oh-my-opencode.json` | `~/.config/opencode/oh-my-opencode.json` | Direct symlink |
| `openai-codex/config.toml` | `~/.codex/config.toml` | **Copy** (not symlink), then Python merge script |

Additionally, `.zshrc` itself creates more symlinks at shell startup (hooks, commands, output-styles) - **duplicating** some of what `install.sh` does.

### What Works Well

1. **Single-repo approach** - everything in one place, easy to clone
2. **Tool-per-directory organization** - each tool has its own directory (claude/, nvim/, opencode/, etc.)
3. **Devcontainer setup** - provides a ready-to-go Linux environment with firewall allowlist
4. **Docker compose volumes** - maps tool configs directly into the container
5. **Sound effects for hooks** - creative UX touch with soundtrack files
6. **Comprehensive README** - good documentation of prerequisites and setup

### What Doesn't Work / Pain Points

1. **Dual symlink paths** - `install.sh` creates some symlinks, `.zshrc` creates others (hooks, commands, output-styles). This is fragile and creates duplicate logic.
2. **macOS-specific hardcoding**:
   - Lazygit config target uses `~/Library/Application Support/` (macOS only; Linux uses `~/.config/lazygit/`)
   - `.zshrc` uses `security find-generic-password` (macOS Keychain)
   - `.zshrc` uses `pbcopy` (macOS clipboard)
   - `.tmux.conf` uses `pbcopy` in copy-mode bindings
   - `.gitconfig` uses `/Applications/Sourcetree.app` and hardcoded `/Users/memorysaver/` paths
   - `.zshrc` has hardcoded `/Users/memorysaver/` paths (bun, pnpm, sst, pulumi, antigravity, opencode)
   - Warp terminal integration is macOS-specific
3. **No platform detection** - `install.sh` has zero `if [[ "$OSTYPE" == "darwin"* ]]` checks
4. **Empty/orphan directories** - `dev-container/` is empty; `.gitmodules` is empty (submodule removed but file remains)
5. **Codex config uses copy+merge** - unlike everything else that symlinks, Codex uses a custom Python merge script - inconsistent
6. **Mixed XDG compliance** - some tools use `~/.config/` (nvim, opencode), others use their own dirs (~/.claude, ~/.codex)
7. **No idempotency** - running `install.sh` twice can fail or produce unexpected results (e.g., recursive nvim symlinks, which the script tries to handle with a special check)
8. **agent-deck config not in install.sh** - the agent-deck config.toml has no symlink setup
9. **Soundtrack files in repo** - 5 MP3s bloat the git history; these should likely be in `.gitignore` or Git LFS

---

## 2. Proposed Structure

### Design Principles

1. **XDG Base Directory compliant** where possible
2. **Platform-aware** with clear macOS/Linux separation
3. **Tool-agnostic installer** that works the same everywhere
4. **Each directory = one stow package** (if using GNU Stow) or one logical unit

### Proposed Tree

```
~/.dotfiles/
├── README.md
├── LICENSE
├── install.sh                  # Smart installer with platform detection
├── Makefile                    # Alternative: `make install`, `make macos`, `make linux`
│
├── shell/                      # Shell configuration (portable)
│   ├── .zshrc                  # Main zshrc (platform-neutral core)
│   ├── zsh/
│   │   ├── aliases.zsh         # All aliases
│   │   ├── functions.zsh       # tmux dev sessions, litellm, etc.
│   │   ├── path.zsh            # PATH setup (platform-aware)
│   │   ├── ai-tools.zsh        # AI tool functions (ccdev, cclitellm, etc.)
│   │   └── platform/
│   │       ├── darwin.zsh       # macOS-specific (Keychain, pbcopy, Warp, Homebrew)
│   │       └── linux.zsh        # Linux-specific (xclip, apt paths)
│   └── .p10k.zsh              # If tracked
│
├── git/                        # Git configuration
│   ├── .gitconfig              # Core config (no hardcoded paths)
│   ├── .gitmessage
│   └── .gitignore_global
│
├── tmux/                       # Tmux configuration
│   ├── .tmux.conf              # Platform-neutral (uses reattach-to-user-namespace conditionally)
│   └── tmux.platform.conf      # Auto-sourced platform-specific overrides
│
├── nvim/                       # Neovim (LazyVim) - unchanged, already XDG-compliant
│   ├── init.lua
│   ├── lua/
│   └── ...
│
├── claude/                     # Claude Code ecosystem
│   ├── settings.json
│   ├── mcp-servers.json
│   ├── statusline.sh
│   ├── CLAUDE.md
│   ├── hooks/
│   ├── commands/
│   ├── output-styles/
│   └── claude-code-router/
│
├── opencode/                   # OpenCode CLI
│   ├── opencode.json
│   └── oh-my-opencode.json
│
├── codex/                      # OpenAI Codex CLI (renamed from openai-codex)
│   └── config.toml
│
├── lazygit/                    # Lazygit (platform-aware target)
│   └── config.yml
│
├── litellm/                    # LiteLLM proxy config
│   ├── config.yaml
│   ├── .env.template
│   └── README.md
│
├── agent-deck/                 # Agent-deck TUI
│   └── config.toml
│
├── assets/                     # Non-config assets
│   └── sounds/                 # Soundtrack files (consider Git LFS)
│       ├── work-work.mp3
│       └── ...
│
├── containers/                 # All container/devcontainer configs
│   ├── .devcontainer/
│   │   ├── devcontainer.json
│   │   ├── docker-compose.yml
│   │   ├── Dockerfile
│   │   └── init-firewall.sh
│   └── README.md
│
└── scripts/                    # Helper scripts
    ├── sync-codex-config.py
    └── platform-detect.sh      # Shared platform detection logic
```

### Key Changes from Current

| Change | Rationale |
|---|---|
| `.zshrc` split into modular files | Monolithic 518-line `.zshrc` is hard to maintain; split by concern |
| Platform-specific code isolated to `shell/zsh/platform/` | Clean separation makes Linux port trivial |
| `dev-container/` removed (empty) | Orphan directory |
| `.gitmodules` cleaned up | Empty file with no active submodules |
| Soundtrack files moved to `assets/sounds/` | Clearer that these aren't config files |
| `openai-codex/` renamed to `codex/` | Shorter, matches the tool's actual name |

---

## 3. Platform Strategy

### Platform Detection

```bash
# scripts/platform-detect.sh
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        arm64|aarch64) echo "arm64" ;;
        x86_64)        echo "x86_64" ;;
        *)             echo "unknown" ;;
    esac
}
```

### Platform-Specific Behaviors

| Feature | macOS | Linux |
|---|---|---|
| Package manager | Homebrew | apt/dnf |
| Lazygit config path | `~/Library/Application Support/lazygit/` | `~/.config/lazygit/` |
| Clipboard in tmux | `pbcopy` | `xclip -selection clipboard` |
| Keychain access | `security find-generic-password` | `secret-tool` or env vars |
| Warp integration | Source warp hook | Skip |
| Homebrew PATH | `/opt/homebrew/bin` (ARM) or `/usr/local/bin` (Intel) | N/A |
| Bun completions path | `/Users/$USER/.bun/_bun` | `$HOME/.bun/_bun` |
| pnpm home | `~/Library/pnpm` | `~/.local/share/pnpm` |

### Strategy: Conditional Sourcing in `.zshrc`

```bash
# In .zshrc (simplified)
DOTFILES="$HOME/.dotfiles"
source "$DOTFILES/shell/zsh/path.zsh"
source "$DOTFILES/shell/zsh/aliases.zsh"
source "$DOTFILES/shell/zsh/functions.zsh"
source "$DOTFILES/shell/zsh/ai-tools.zsh"

# Platform-specific
case "$(uname -s)" in
    Darwin*) source "$DOTFILES/shell/zsh/platform/darwin.zsh" ;;
    Linux*)  source "$DOTFILES/shell/zsh/platform/linux.zsh" ;;
esac
```

### What's macOS-Specific vs Portable (Current Analysis)

**macOS-specific (must be conditionally loaded):**
- `security find-generic-password` for Keychain (`.zshrc` lines 493-516)
- `pbcopy` usage in `.tmux.conf` (lines 78, 168-169)
- `~/Library/Application Support/lazygit/` path (`install.sh` line 29-30)
- `/Applications/Sourcetree.app` in `.gitconfig` (line 16-18)
- Warp terminal integration (`.zshrc` line 434)
- Hardcoded `/Users/memorysaver/` paths (`.zshrc` lines 437, 472, 480, 483, 486, 489)
- `pnpm` home at `~/Library/pnpm` (`.zshrc` line 472)

**Fully portable (works on both):**
- Neovim config (`~/.config/nvim`)
- Claude Code config (`~/.claude/`)
- OpenCode config (`~/.config/opencode/`)
- Codex config (`~/.codex/`)
- Agent-deck config
- tmux core config (minus clipboard bindings)
- LiteLLM config
- Git config (minus Sourcetree references)
- All AI tool shell functions (ccdev, opendev, codexdev, etc.) - assuming tools are installed
- Soundtrack files
- All Python scripts
- MCP server configurations

---

## 4. Symlink Map

### Universal Symlinks (Both Platforms)

| Source | Target | Notes |
|---|---|---|
| `shell/.zshrc` | `~/.zshrc` | Modular, sources platform files |
| `git/.gitconfig` | `~/.gitconfig` | Remove hardcoded macOS paths |
| `git/.gitmessage` | `~/.gitmessage` | |
| `tmux/.tmux.conf` | `~/.tmux.conf` | Platform-aware clipboard |
| `nvim/` | `~/.config/nvim` | Directory symlink |
| `claude/settings.json` | `~/.claude/settings.json` | |
| `claude/mcp-servers.json` | `~/.claude/mcp-servers.json` | |
| `claude/statusline.sh` | `~/.claude/statusline.sh` | |
| `claude/hooks/*` | `~/.claude/hooks/` | Per-file symlinks |
| `claude/commands/*` | `~/.claude/commands/` | Per-file symlinks |
| `claude/output-styles/` | `~/.claude/output-styles` | Directory symlink |
| `opencode/opencode.json` | `~/.config/opencode/opencode.json` | |
| `opencode/oh-my-opencode.json` | `~/.config/opencode/oh-my-opencode.json` | |
| `codex/config.toml` | `~/.codex/config.toml` | Switch from copy to symlink |
| `agent-deck/config.toml` | `~/.config/agent-deck/config.toml` | Add to install |

### macOS-Only Symlinks

| Source | Target |
|---|---|
| `lazygit/config.yml` | `~/Library/Application Support/lazygit/config.yml` |

### Linux-Only Symlinks

| Source | Target |
|---|---|
| `lazygit/config.yml` | `~/.config/lazygit/config.yml` |

---

## 5. Migration Plan

### Phase 0: Pre-Migration Safety (Day 1)

1. **Commit current state** - ensure everything is committed and pushed
2. **Create backup branch** - `git checkout -b backup/pre-restructure`
3. **Document current symlink state** - run `ls -la ~/ | grep "\->"` to capture current symlinks
4. **Test devcontainer still works** - ensure container builds before making changes

### Phase 1: Clean Up Dead Code (Day 1)

1. Remove empty `dev-container/` directory
2. Remove empty `.gitmodules` file
3. Remove Sourcetree references from `.gitconfig` (or make conditional)
4. Remove hardcoded `/Users/memorysaver/` paths from `.zshrc` (use `$HOME`)
5. Rename `openai-codex/` to `codex/`

**Risk: Low.** These are cleanups with no behavioral change.

### Phase 2: Modularize `.zshrc` (Day 2-3)

1. Extract AI tool functions into `shell/zsh/ai-tools.zsh`
2. Extract macOS-specific code into `shell/zsh/platform/darwin.zsh`
3. Create `shell/zsh/platform/linux.zsh` with Linux equivalents
4. Extract PATH setup into `shell/zsh/path.zsh`
5. Extract aliases into `shell/zsh/aliases.zsh`
6. Update `.zshrc` to source modular files
7. Test that shell starts correctly after changes

**Risk: Medium.** Shell config changes can break login. Test in a subshell first (`zsh -l`).

### Phase 3: Fix Platform-Specific Symlinks (Day 3)

1. Update `install.sh` to detect platform
2. Add lazygit symlink that targets correct path per platform
3. Make `.tmux.conf` clipboard bindings platform-aware:
   ```tmux
   if-shell "uname | grep -q Darwin" \
       "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'pbcopy'" \
       "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -selection clipboard'"
   ```
4. Add agent-deck config to install script

**Risk: Low-Medium.** Straightforward conditionals.

### Phase 4: Consolidate Symlink Logic (Day 4)

1. Remove duplicate symlink creation from `.zshrc` (hooks, commands, output-styles)
2. Move ALL symlink creation into `install.sh`
3. Make `install.sh` idempotent (check before creating, don't fail on re-run)
4. Switch Codex from copy+merge to symlink (simpler, consistent)

**Risk: Medium.** Need to verify that removing `.zshrc` symlinks doesn't break anything when `install.sh` hasn't been re-run.

### Phase 5: Reorganize Assets (Day 5)

1. Move soundtrack files to `assets/sounds/`
2. Update hook scripts to reference new path
3. Move `.spacemacs` to `editor/.spacemacs` or remove entirely
4. Keep `.github/` at root (GitHub requires it there for Actions)

**Risk: Low.** Just moving files and updating references.

### Phase 6: Test on Linux (Day 6)

1. Test full install in the devcontainer (Linux environment)
2. Verify all symlinks resolve correctly
3. Verify shell starts without errors
4. Verify AI tools (Claude, OpenCode, Codex) can find their configs

### Rollback Strategy

At any point, if something breaks:
```bash
git checkout backup/pre-restructure -- .zshrc install.sh
```
Each phase should be its own commit for granular rollback.

---

## 6. Tool Recommendation

### Options Evaluated

| Tool | Pros | Cons |
|---|---|---|
| **GNU Stow** | Zero dependencies (just Perl), convention-based, widely used | Can't handle platform-conditional symlinks, no templating |
| **chezmoi** | Templates, platform conditionals built-in, encryption for secrets | Heavy dependency (Go binary), learning curve, over-engineered for this scale |
| **yadm** | Git wrapper approach, built-in alt files for platform variants | Less popular, limited community |
| **Custom install.sh** | Zero dependencies, full control, already exists, easy to understand | Must implement everything yourself, no dry-run, manual idempotency |

### Recommendation: **Enhanced Custom Script (install.sh)** with Optional Stow Migration Later

**Rationale:**

1. **The repo is already 90% there** with the current `install.sh`. The main gaps are platform detection and consolidating the duplicate symlink logic from `.zshrc`.

2. **GNU Stow won't handle the hard parts.** The real complexity is platform-conditional paths (lazygit on macOS vs Linux, clipboard tools, Keychain access). Stow can't do this.

3. **chezmoi is overkill.** With ~20 symlinks and 2 platforms, the Go template engine and encryption features aren't needed.

4. **The devcontainer already handles Linux.** The docker-compose.yml already maps configs into the container with volume mounts.

### Recommended install.sh Improvements

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
PLATFORM="$(uname -s)"

# Utility: create symlink only if target doesn't already point to source
ensure_link() {
    local src="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        return 0  # Already correct
    fi
    [ -e "$target" ] && rm -rf "$target"
    ln -sfv "$src" "$target"
}

# Universal symlinks
ensure_link "$DOTFILES/shell/.zshrc" "$HOME/.zshrc"
ensure_link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
ensure_link "$DOTFILES/git/.gitmessage" "$HOME/.gitmessage"
ensure_link "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
ensure_link "$DOTFILES/nvim" "$HOME/.config/nvim"
# ... claude, opencode, codex, etc.

# Platform-specific
case "$PLATFORM" in
    Darwin*)
        ensure_link "$DOTFILES/lazygit/config.yml" "$HOME/Library/Application Support/lazygit/config.yml"
        ;;
    Linux*)
        ensure_link "$DOTFILES/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
        ;;
esac
```

### Future: When to Adopt Stow or chezmoi

Consider switching to **chezmoi** if:
- You add 3+ machines with divergent configs
- You need secret management (API keys in dotfiles)
- You want automatic config updates across machines

Consider **GNU Stow** if:
- You want to simplify the script but don't need templating
- All your configs fit the `package/path/to/target` convention

For now, the enhanced custom script is the pragmatic choice.

---

## Summary of Key Findings

1. **The repo is well-organized by tool** but has **dual symlink creation** (install.sh + .zshrc) that should be consolidated
2. **macOS assumptions are pervasive** - ~12 hardcoded references need platform conditionals
3. **The .zshrc is doing too much** at 518 lines - modularizing it is the highest-impact change
4. **The devcontainer is already good Linux support** - the main gap is the bare-metal Linux install path
5. **GNU Stow and chezmoi are not worth the migration cost** - an improved install.sh with platform detection solves the real problems
6. **Quick wins**: remove dead code (empty dirs, .gitmodules), replace hardcoded paths with `$HOME`, rename openai-codex to codex
7. **The Codex copy+merge pattern should become a symlink** for consistency
8. **Soundtrack files (5 MP3s) are in the git history** - consider Git LFS or `.gitignore` + separate download
