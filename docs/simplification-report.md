# Dotfiles Simplification Report

## Repository Overview

- **Total files**: ~60 (excluding `.git/`)
- **Core configs**: `.zshrc` (19KB), `.tmux.conf` (5KB), `.spacemacs` (23KB)
- **AI tool configs**: Claude Code, OpenCode, Codex CLI, LiteLLM, agent-deck, claude-code-router
- **Soundtrack**: 5 MP3 files (~170KB total)
- **5 Python hook scripts** with massive code duplication

---

## 1. Files to Remove

### 1.1 `.spacemacs` — STRONG candidate for removal
- **Size**: 23KB, 382 lines
- **Last meaningful edit**: Nov 4, 2023 (over 2 years ago)
- **Evidence of staleness**: The entire file is 95% boilerplate default Spacemacs config comments. The `user-init` and `user-config` functions are completely empty. The only customization is the language layers list (Python, JS, TypeScript, Terraform, SQL, Rust, Ruby).
- **The user now uses nvim**: The repo has a full `nvim/` directory with LazyVim config, claude-code.nvim, toggleterm, etc. This is clearly the active editor.
- **install.sh still symlinks it**: Line 14 creates a symlink to `~/.spacemacs`
- **Recommendation**: Remove `.spacemacs` and its symlink in `install.sh`. If needed for nostalgia, move to a `archive/` branch.

### 1.2 `dev-container/` — Empty directory
- **Contents**: Completely empty (just `.` and `..`)
- **Likely replaced by**: `.devcontainer/` which has a full Docker-based dev environment
- **Recommendation**: Delete this empty directory.

### 1.3 `nvim/lua/plugins/example.lua` — Dead example code
- **Line 3**: `if true then return {} end` — the entire file is disabled
- **Content**: LazyVim boilerplate example that ships with the starter template
- **Recommendation**: Delete. It adds no value and creates confusion about what plugins are actually active.

### 1.4 `nvim/lua/plugins/toggleterm-readme.md` — Documentation in wrong place
- **Location**: Inside `lua/plugins/` alongside Lua files
- **Recommendation**: Delete. Plugin README belongs in the plugin repo, not in your config.

### 1.5 `.gitmodules` — Empty file
- **Contents**: Empty (0 bytes effectively)
- **install.sh references**: Lines 9-11 try to update a submodule `claude/claude-code-requirements-builder` that no longer exists
- **Recommendation**: Remove `.gitmodules` and the submodule references in `install.sh` (lines 8-11 and lines 42-46).

### 1.6 `scripts/setup-mcp.sh` — Redundant
- **Purpose**: Adds MCP servers via `claude mcp add-json` by parsing `mcp-servers.json`
- **But**: The `mcp-servers.json` is already symlinked by `install.sh` (line 50), and Claude Code reads it directly from `~/.claude/mcp-servers.json`
- **Recommendation**: Delete. The symlink approach is simpler and already works.

### 1.7 `claude/claude-code-router/.env` — Should not be in repo
- **Contents**: Shell commands to read 1Password secrets (`op read ...`)
- **Issue**: This isn't a real `.env` file — it contains shell command syntax, not KEY=VALUE pairs. It's not sourced anywhere; the `ccrcode()` function in `.zshrc` uses `op read` directly.
- **Recommendation**: Delete. The secrets are already handled inline in `.zshrc`'s `ccrcode()` function.

---

## 2. Files to Consolidate

### 2.1 Claude Hook Scripts — MASSIVE duplication (5 files, ~500 lines total)

**The problem**: All 5 Python hook scripts share identical `play_audio_macos()`, `play_audio_fallback()`, and `play_audio()` functions (copy-pasted verbatim). This is ~56 lines duplicated 5 times = ~280 lines of redundant code.

| File | Unique logic | Audio file played |
|------|-------------|-------------------|
| `session_start.py` | None - just plays audio | `battle-cruiser-operational.mp3` |
| `user_prompt_submit.py` | Prompt caching to disk | `work-work.mp3` |
| `stop.py` | Read prompt cache, macOS notification | `work-complete.mp3` |
| `notification.py` | Keyword matching on message | `Jinx-Everybody-Panic.mp3` |
| `pre_tool_use.py` | Check tool_name == "Task" | `Teemo-On-Duty.mp3` |

**Recommendation**: Extract shared audio logic into a single `_audio_utils.py` module:

```
claude/hooks/
├── _audio_utils.py        # play_audio_macos(), play_audio_fallback(), play_audio()
├── session_start.py       # ~15 lines (import + play)
├── user_prompt_submit.py  # ~35 lines (import + prompt cache + play)
├── stop.py                # ~40 lines (import + cache read + notify + play)
├── notification.py        # ~25 lines (import + keyword check + play)
└── pre_tool_use.py        # ~20 lines (import + tool check + play)
```

**Impact**: ~280 lines removed, single place to update audio logic.

### 2.2 MCP Server Config — Duplicated across 4 files

The Context7 MCP server is defined identically in:
1. `claude/mcp-servers.json` (for Claude Code)
2. `openai-codex/config.toml` (for Codex CLI)
3. `agent-deck/config.toml` (for agent-deck)
4. `opencode/opencode.json` (for OpenCode)

And `chrome-devtools` MCP is in both:
1. `claude/mcp-servers.json`
2. `openai-codex/config.toml`

**Recommendation**: Accept this as necessary config for different tools, but document it in a single place. Consider a `shared/mcp-servers.json` as a source of truth, with a small script to sync to each tool's format.

### 2.3 `.tmux.conf` — Duplicate settings from agent-deck

Lines 1-139 are the user's original tmux config. Lines 140-170 are agent-deck's additions. There are explicit conflicts:

| Setting | Original (line) | Agent-deck (line) |
|---------|-----------------|-------------------|
| `default-terminal` | `"screen-256color"` (L13) | `"tmux-256color"` (L146) |
| `escape-time` | `0` (L34) | `0` (L151) — redundant |
| `history-limit` | `50000` (L20) | `50000` (L152) — redundant |
| `mouse` | `on` (L10) | `on` (L155) — redundant |

**Recommendation**: Merge the agent-deck additions into the main config body and remove the duplicate settings. The agent-deck section adds useful scroll/copy bindings (lines 159-169) that should stay but be integrated into the relevant sections.

### 2.4 `.gitignore` — Python-specific, should be broader

The `.gitignore` is entirely a Python project template (Django, Flask, Scrapy, Celery, etc.) — clearly auto-generated from GitHub's Python template. But this is a **dotfiles repo**, not a Python project.

**Recommendation**: Replace with a minimal dotfiles-appropriate `.gitignore`:
```
.env
*.local
.DS_Store
.claude/debug/
__pycache__/
```

---

## 3. Code to Simplify

### 3.1 `.zshrc` — 518 lines, overly complex

**Commented-out boilerplate (lines 15-112)**: ~98 lines of oh-my-zsh commented-out options that have never been uncommented. These are the default oh-my-zsh template comments.

**Recommendation**: Delete all commented-out oh-my-zsh defaults (lines 15-77, 93-112). Keep only the actual settings. This alone removes ~80 lines.

**LiteLLM management (lines 152-405)**: ~254 lines dedicated to LiteLLM proxy management. The `litellm-start()` function alone is 96 lines with extensive API key validation, interactive prompts, and template copying.

**Recommendation**: Move LiteLLM functions to a separate sourced file: `~/.dotfiles/shell/litellm.sh`. Same for the dev tmux session helpers (`_create_dev_tmux_session`, `ccdev`, `cclitedev`, `codexdev`, etc.) — move to `~/.dotfiles/shell/dev-envs.sh`.

Suggested `.zshrc` structure:
```zsh
# Core: p10k, oh-my-zsh, plugins (~30 lines)
# PATH setup (~15 lines)
# Aliases (~5 lines)
# Source modular configs:
source ~/.dotfiles/shell/dev-envs.sh      # tmux dev environments
source ~/.dotfiles/shell/litellm.sh       # LiteLLM proxy management
source ~/.dotfiles/shell/claude-hooks.sh  # Claude Code symlinks
source ~/.dotfiles/shell/claude-token.sh  # OAuth token export
```

**Impact**: `.zshrc` drops from 518 lines to ~100 lines.

### 3.2 `.zshrc` — Claude Code symlinks block (lines 444-466)

This runs **every time a shell starts**, creating symlinks even when nothing has changed. It also creates directories that already exist.

**Recommendation**: Move to `install.sh` where it belongs (one-time setup), or add a simple check:
```zsh
# Only re-link if dotfiles hooks are newer than symlinks
```

### 3.3 `.zshrc` — OAuth token extraction (lines 492-516)

The `export_claude_code_token()` function (lines 493-511) and the auto-export block (lines 514-516) are redundant — the auto-export does the same thing as the function but silently. The function is only useful if the user wants to manually re-export.

**Recommendation**: Keep only the silent auto-export block. Remove the interactive function unless it's actually called.

### 3.4 `.zshrc` — PATH duplication and ordering

PATH is modified in 11 different places throughout the file:
- Line 3: fpath for completions
- Line 415: pyenv
- Line 421: poetry/local bin
- Line 425: openssl
- Line 441: bun
- Line 442: cargo
- Line 472-476: pnpm
- Line 480: sst
- Line 483: pulumi
- Line 486: antigravity
- Line 489: opencode
- Line 517: homebrew (should be FIRST, is LAST)

**Critical issue**: Homebrew's PATH (`/opt/homebrew/bin`) is added last (line 517) but should be first to ensure system tools are found. This is a common source of bugs.

**Recommendation**: Consolidate all PATH additions into a single block near the top of the file, ordered by priority.

### 3.5 `install.sh` — Dead submodule references

Lines 8-11 reference `claude/claude-code-requirements-builder` submodule that no longer exists (`.gitmodules` is empty).
Lines 42-46 try to symlink commands from this non-existent submodule.

**Recommendation**: Remove lines 8-11 and 42-46.

### 3.6 `install.sh` — Claude commands symlink

Lines 34-39 and 55-58 create symlinks for Claude commands and commands from the requirements builder. But the commands directory doesn't seem to exist in the repo currently.

**Recommendation**: Verify if `claude/commands/` exists and has content. If not, remove these lines.

### 3.7 `.gitconfig` — SourceTree references

Lines 16-21 reference SourceTree, a GUI Git client. If not actively used, these are dead config.

**Recommendation**: Verify if SourceTree is still used. If not, remove the difftool and mergetool sections.

---

## 4. Quick Wins

### 4.1 Consolidate hook audio utils (saves ~280 lines)
Extract the triplicated `play_audio*` functions into `_audio_utils.py`. Highest impact, lowest risk.

### 4.2 Delete dead files (5 minutes)
- Remove `dev-container/` (empty)
- Remove `nvim/lua/plugins/example.lua` (disabled)
- Remove `nvim/lua/plugins/toggleterm-readme.md` (misplaced doc)
- Remove `.gitmodules` (empty)
- Remove `scripts/setup-mcp.sh` (redundant)
- Remove `claude/claude-code-router/.env` (unused)

### 4.3 Clean `.zshrc` comments (saves ~80 lines)
Delete the oh-my-zsh boilerplate comments that have never been used.

### 4.4 Merge `.tmux.conf` duplicate settings
Remove the 4 redundant settings in the agent-deck section that duplicate the main config.

### 4.5 Fix Homebrew PATH ordering
Move `export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"` from line 517 to near the top.

### 4.6 Remove `.spacemacs` and update `install.sh`
If nvim is the primary editor (evidence strongly suggests this), remove Spacemacs config entirely.

---

## Summary of Impact

| Category | Items | Lines Saved | Risk |
|----------|-------|-------------|------|
| Remove dead files | 7 files | ~400+ lines | Very low |
| Consolidate hook scripts | 5 → 6 files (with shared module) | ~280 lines | Low |
| Clean .zshrc | Comments + modularize | ~400 lines from .zshrc | Medium |
| Merge .tmux.conf | Remove duplication | ~15 lines | Very low |
| Fix .gitignore | Replace Python template | ~100 lines | Very low |
| Remove .spacemacs | 1 file | 382 lines | Low (if nvim is primary) |
| **Total** | | **~1,500+ lines** | |

### Recommended Priority Order:
1. Delete dead files (quick wins, zero risk)
2. Extract hook audio utils (biggest quality improvement)
3. Remove .spacemacs (if confirmed unused)
4. Clean .zshrc comments
5. Fix PATH ordering
6. Modularize .zshrc functions
7. Merge .tmux.conf
8. Replace .gitignore
