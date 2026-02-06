# Agentic Coding Tool Configuration Report

## 1. Current Config Inventory

### 1.1 Claude Code (`claude/`)

**Primary Config: `settings.json`**
- **Model**: `opus` (Claude Opus 4.6)
- **Permissions**: Granular allow-list for bash commands (`rg`, `find`, `grep`, `mkdir`, `cp`, `ls`, `cat`, `pnpm run`, `git add/commit/push`, `gh pr *`), WebFetch for specific domains (`docs.anthropic.com`, `raw.githubusercontent.com`, `github.com`), and MCP tools (`context7`)
- **MCP Servers**: `context7` enabled via `enabledMcpjsonServers`
- **Plugins**: 14 plugins enabled including `frontend-design`, `plugin-dev`, `code-review`, `ralph-loop`, `code-simplifier`, `example-skills`, `typescript-lsp`, `superpowers`, `agent-browser`, `mgrep`, `agent-deck`, `search-and-research`, `context-management`
- **Hooks**: 5 lifecycle hooks (SessionStart, Stop, UserPromptSubmit, Notification, PreToolUse) — all are Python scripts that play audio notifications via `afplay` (macOS) with `pygame` fallback
- **Teammate Mode**: `tmux` with experimental agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- **Status Line**: Custom bash script showing dir, git branch, ccusage, and datetime
- **Always Thinking**: Enabled

**MCP Servers: `mcp-servers.json`**
- `context7`: Library documentation lookup via `@upstash/context7-mcp`
- `chrome-devtools`: Chrome DevTools MCP via `chrome-devtools-mcp@latest`

**System Prompt: `CLAUDE.md`**
- Persona: Senior developer returning to modern practices
- Focus: Modern tooling, framework evolution, deployment patterns
- Guidelines: Technical competency assumed, best practices first, tradeoff analysis, performance at scale
- Standards: Code quality, testing strategy, security, observability

**Output Styles: `output-styles/cloudflare-workers-monorepo-maintainer.md`**
- Specialized Cloudflare Workers monorepo assistant
- Full-stack tech stack definition (TanStack Start, shadcn/ui, Tailwind, tRPC, D1, Drizzle, Better-Auth, Stripe, Workers AI)
- SDLC integration via `just` commands
- Tmux integration for interactive processes

**Claude Code Router: `claude-code-router/`**
- **config.json**: Routes Claude Code requests through OpenRouter/Groq to alternative models
  - Providers: OpenRouter (Kimi K2), Groq (Kimi K2 Instruct)
  - Router: All routes (default, fast, reasoning) point to `openrouter,moonshotai/kimi-k2`
- **.env**: API keys pulled from 1Password CLI (`op read`)

**Hooks Detail:**

| Hook | File | Sound | Trigger |
|------|------|-------|---------|
| SessionStart | `session_start.py` | `battle-cruiser-operational.mp3` | Claude Code starts/resumes |
| Stop | `stop.py` | `work-complete.mp3` | Task completion + macOS notification |
| UserPromptSubmit | `user_prompt_submit.py` | `work-work.mp3` | User submits prompt; also caches prompt for Stop hook |
| Notification | `notification.py` | `Jinx-Everybody-Panic.mp3` | Permission/input requests (keyword-matched) |
| PreToolUse | `pre_tool_use.py` | `Teemo-On-Duty.mp3` | Task (subagent) tool starts |

**Hook Architecture Notes:**
- All 5 hooks share ~60 lines of identical audio playback boilerplate (`play_audio_macos`, `play_audio_fallback`, `play_audio`)
- UserPromptSubmit caches the prompt to `~/.claude/prompts/{session_id}.txt`
- Stop hook reads the cached prompt to show "Completed: {prompt}" in macOS notification
- All hooks use `uv run --with pygame` for execution
- All hooks exit 0 on error to never block Claude Code

**Status Line: `statusline.sh`**
- Shows: directory name, git branch, ccusage (via `npx ccusage@latest statusline`), datetime
- Runs `npx` on every status refresh (potential latency issue)

---

### 1.2 OpenCode (`opencode/`)

**Primary Config: `opencode.json`**
- **MCP Servers**: `mgrep` (local binary) and `context7` (same npx command as Claude)
- **Plugins**: `oh-my-opencode@latest`, `opencode-antigravity-auth@1.4.3`
- **Custom Providers (Google namespace)**: 5 models via Antigravity proxy:
  - Gemini 3 Pro/Flash (Antigravity)
  - Claude Sonnet 4.5 / Sonnet 4.5 Thinking / Opus 4.5 Thinking (Antigravity)
  - Various thinking level variants (low, medium, high, max)

**Agent Config: `oh-my-opencode.json`**
- **Named Agents**: 10 agents with specific model assignments:
  - `sisyphus`, `prometheus`, `metis`: Claude Opus 4.5 (GitHub Copilot) — max variant
  - `hephaestus`: GPT 5.2 Codex — medium variant
  - `oracle`, `momus`: GPT 5.2 — high/medium variant
  - `librarian`, `atlas`: Claude Sonnet 4.5 (GitHub Copilot)
  - `explore`: GPT 5 Mini (GitHub Copilot)
  - `multimodal-looker`: Gemini 3 Flash (Google)
- **Task Categories**: 8 categories mapping task types to models:
  - `visual-engineering`: Gemini 3 Pro
  - `ultrabrain`/`deep`: GPT 5.2 Codex (xhigh/medium)
  - `artistry`: Gemini 3 Pro (max)
  - `quick`: Claude Haiku 4.5
  - `unspecified-low`/`unspecified-high`: Claude Sonnet 4.5
  - `writing`: Gemini 3 Flash

---

### 1.3 OpenAI Codex (`openai-codex/`)

**Config: `config.toml`**
- **Default Model**: `gpt-5-codex` via `openai` provider
- **Sandbox Mode**: `workspace-write`
- **Additional Providers**: Groq, OpenRouter (same URLs as litellm/router)
- **Profiles**: `k2` profile using OpenRouter -> `moonshotai/kimi-k2`
- **MCP Servers**: `context7` (same npx command) + `chrome-devtools` (same as Claude)

**Sync Script: `scripts/sync-codex-config.py`**
- Syncs dotfiles config to `~/.codex/config.toml`
- Preserves existing `projects` section (trust settings)
- Creates backup before overwrite
- Manual TOML writer (with tomlkit optional dependency)

---

### 1.4 Agent Deck (`agent-deck/`)

**Config: `config.toml`**
- **Default Tool**: `claude`
- **Claude Integration**: `dangerous_mode = true` (auto-approve all)
- **Worktree**: Default location `subdirectory`, auto-cleanup enabled
- **Global Search**: Enabled, tier auto, 90 recent days
- **MCP Pool**: Enabled but with conservative defaults (no auto-start, fallback to stdio)
- **Updates**: Auto-update enabled, 24h check interval
- **MCP Servers**: `context7` (same npx command)

---

### 1.5 LiteLLM (`litellm/`)

**Config: `config.yaml`**
- **Model List**: 4 route groups:
  - `anthropic/*` -> routes through `openrouter/*` (with sampling params)
  - `openrouter/*` -> direct pass-through (with sampling params)
  - `groq/*` -> direct Groq API
  - `cerebras/*` -> direct Cerebras API
- **Sampling Defaults**: `max_tokens: 65536`, `repetition_penalty: 1.05`, `temperature: 0.7`, `top_k: 20`, `top_p: 0.8`

**Environment: `.env.template`**
- Placeholder keys for: LiteLLM master key, OpenRouter, Groq, Cerebras

---

### 1.6 Scripts (`scripts/`)

**`setup-mcp.sh`**
- Reads `claude/mcp-servers.json` and registers each server via `claude mcp add-json --scope user`
- Clears MCP auth cache first (`~/.mcp-auth`)
- Requires `jq`

**`sync-codex-config.py`**
- One-way sync: dotfiles -> `~/.codex/config.toml`
- Preserves project trust settings
- Backup before overwrite

---

## 2. Overlap Analysis

### 2.1 MCP Server Definitions (Duplicated 4 Times)

The `context7` MCP server is defined identically in **4 separate locations**:

| Location | Format | Command |
|----------|--------|---------|
| `claude/mcp-servers.json` | JSON | `npx -y @upstash/context7-mcp` |
| `opencode/opencode.json` | JSON | `npx -y @upstash/context7-mcp` |
| `openai-codex/config.toml` | TOML | `npx -y @upstash/context7-mcp` |
| `agent-deck/config.toml` | TOML | `npx -y @upstash/context7-mcp` |

The `chrome-devtools` MCP server is defined in **2 locations**:

| Location | Format | Command |
|----------|--------|---------|
| `claude/mcp-servers.json` | JSON | `npx chrome-devtools-mcp@latest` |
| `openai-codex/config.toml` | TOML | `npx chrome-devtools-mcp@latest` |

### 2.2 Model Provider / API Routes (Duplicated 3 Times)

OpenRouter and Groq provider configurations appear in:

| Location | OpenRouter | Groq | Cerebras |
|----------|-----------|------|----------|
| `openai-codex/config.toml` | Yes (base_url + env_key) | Yes | No |
| `litellm/config.yaml` | Yes (wildcard route) | Yes | Yes |
| `claude-code-router/config.json` | Yes (full URL + key placeholder) | Yes | No |

### 2.3 API Key Management (Fragmented)

| Location | Method |
|----------|--------|
| `litellm/.env.template` | Manual placeholder file |
| `claude-code-router/.env` | 1Password CLI (`op read`) |
| `openai-codex/config.toml` | Environment variable references |
| `opencode/opencode.json` | Implicit (env vars or plugin auth) |

### 2.4 Model Routing Strategies

Each tool has a different model routing approach:

| Tool | Strategy | Default Model |
|------|----------|---------------|
| Claude Code | Direct Anthropic API | Opus 4.6 |
| Claude Code Router | OpenRouter proxy -> Kimi K2 | Kimi K2 |
| OpenCode | Multi-provider (Google/Antigravity, GitHub Copilot) | Configurable |
| oh-my-opencode | Agent-specific model routing | Per-agent |
| Codex | OpenAI direct + profiles | GPT 5 Codex |
| LiteLLM | Wildcard proxy routing | Provider-dependent |
| Agent Deck | Delegates to Claude | Claude (via tool) |

### 2.5 Instruction/System Prompt Overlap

- `claude/CLAUDE.md`: Comprehensive development guidelines
- `opencode/`: No equivalent system prompt in dotfiles (handled by oh-my-opencode plugin)
- `openai-codex/`: No instruction file (Codex uses its own system prompt)
- `claude/output-styles/`: Specialized per-project persona (Cloudflare Workers)

### 2.6 Hook/Audio Boilerplate Duplication

All 5 hook scripts contain **identical** audio playback functions:
- `play_audio_macos()` — ~8 lines each
- `play_audio_fallback()` — ~12 lines each
- `play_audio()` — ~10 lines each

That's ~150 lines of duplicated code across 5 files that could be a single shared module.

---

## 3. Unified Architecture

### 3.1 Proposed Directory Structure

```
~/.dotfiles/
├── shared/                          # Shared components across all tools
│   ├── mcp-servers.yaml             # Single source of truth for MCP servers
│   ├── providers.yaml               # Unified provider/model definitions
│   ├── instructions/
│   │   ├── base-system.md           # Core development guidelines (current CLAUDE.md)
│   │   └── cloudflare-workers.md    # Project-specific (current output-style)
│   └── secrets.env.template         # Unified API key template
│
├── claude/                          # Claude Code specific
│   ├── settings.json                # Permissions, plugins, hooks, teammates
│   ├── CLAUDE.md                    # -> imports from shared/instructions/base-system.md
│   ├── hooks/
│   │   ├── _audio.py                # Shared audio playback module
│   │   ├── session_start.py         # Thin wrapper: import _audio; play(sound)
│   │   ├── stop.py
│   │   ├── user_prompt_submit.py
│   │   ├── notification.py
│   │   └── pre_tool_use.py
│   ├── statusline.sh
│   ├── output-styles/
│   │   └── cloudflare-workers-monorepo-maintainer.md
│   └── claude-code-router/
│       └── config.json
│
├── opencode/
│   ├── opencode.json                # Generated from shared/mcp-servers.yaml + local overrides
│   └── oh-my-opencode.json          # Agent/category routing (OpenCode-specific)
│
├── openai-codex/
│   └── config.toml                  # Generated from shared/providers.yaml + shared/mcp-servers.yaml
│
├── agent-deck/
│   └── config.toml                  # Generated with shared MCP servers injected
│
├── litellm/
│   ├── config.yaml                  # Generated from shared/providers.yaml
│   └── .env.template                # -> symlink or generated from shared/secrets.env.template
│
├── scripts/
│   ├── generate-configs.py          # Master config generator
│   └── sync-codex-config.py
│
└── soundtrack/                      # Audio files for hooks
    ├── battle-cruiser-operational.mp3
    ├── work-work.mp3
    ├── work-complete.mp3
    ├── Jinx-Everybody-Panic.mp3
    └── Teemo-On-Duty.mp3
```

### 3.2 Design Principles

1. **Single Source of Truth**: MCP servers, providers, and API keys defined once in `shared/`
2. **Generate, Don't Duplicate**: A `generate-configs.py` script transforms shared definitions into tool-specific formats (JSON, TOML, YAML)
3. **Tool-Specific Overrides**: Each tool directory contains only what's unique to that tool
4. **DRY Hooks**: Extract shared audio module, reduce each hook to ~15 lines
5. **Layered Instructions**: Base system prompt + project-specific output styles

---

## 4. Shared Components

### 4.1 MCP Server Registry (`shared/mcp-servers.yaml`)

```yaml
# Single source of truth for all MCP server definitions
servers:
  context7:
    command: npx
    args: ["-y", "@upstash/context7-mcp"]
    description: "Library documentation lookup"
    targets: [claude, opencode, codex, agent-deck]  # Which tools use this

  chrome-devtools:
    command: npx
    args: ["chrome-devtools-mcp@latest"]
    description: "Chrome DevTools integration"
    targets: [claude, codex]

  mgrep:
    type: local
    command: [mgrep, mcp]
    description: "Mixed-bread semantic search"
    targets: [opencode]  # OpenCode only
```

### 4.2 Provider Registry (`shared/providers.yaml`)

```yaml
providers:
  openrouter:
    name: OpenRouter
    base_url: "https://openrouter.ai/api/v1"
    env_key: OPENROUTER_API_KEY
    models:
      - moonshotai/kimi-k2

  groq:
    name: Groq
    base_url: "https://api.groq.com/openai/v1"
    env_key: GROQ_API_KEY
    models:
      - moonshotai/kimi-k2-instruct

  cerebras:
    name: Cerebras
    base_url: "https://api.cerebras.ai/v1"
    env_key: CEREBRAS_API_KEY

defaults:
  max_tokens: 65536
  temperature: 0.7
  top_k: 20
  top_p: 0.8
```

### 4.3 Shared Audio Module (`claude/hooks/_audio.py`)

```python
"""Shared audio playback for Claude Code hooks"""
import subprocess, sys
from pathlib import Path

SOUNDTRACK_DIR = Path.home() / '.dotfiles' / 'soundtrack'

def play(filename: str) -> bool:
    path = SOUNDTRACK_DIR / filename
    if not path.exists():
        return False
    try:
        subprocess.Popen(['afplay', str(path)],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL)
        return True
    except FileNotFoundError:
        try:
            import pygame, threading
            def _play():
                pygame.mixer.init()
                pygame.mixer.music.load(str(path))
                pygame.mixer.music.play()
            threading.Thread(target=_play, daemon=True).start()
            return True
        except Exception:
            return False
```

Each hook becomes ~15 lines instead of ~90:

```python
#!/usr/bin/env python3
"""SessionStart: Play startup sound"""
import json, sys
sys.path.insert(0, str(Path(__file__).parent))
from _audio import play

def main():
    try:
        input_data = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}
        if play('battle-cruiser-operational.mp3'):
            print("Claude Code ready for action!")
        sys.exit(0)
    except Exception:
        sys.exit(0)

if __name__ == "__main__":
    main()
```

### 4.4 Instruction Layering

```
shared/instructions/base-system.md     -> Core development philosophy (current CLAUDE.md)
claude/CLAUDE.md                       -> Can include/reference base-system.md
claude/output-styles/*.md              -> Project-specific personas
```

OpenCode and Codex don't have native instruction file support in the same way, but:
- OpenCode: oh-my-opencode can be configured with agent-level system prompts
- Codex: Supports `AGENTS.md` or instruction files per-project

---

## 5. Sync Strategy

### 5.1 Current State

| Mechanism | Source | Target | Status |
|-----------|--------|--------|--------|
| `setup-mcp.sh` | `claude/mcp-servers.json` | `claude mcp add-json` | Manual run |
| `sync-codex-config.py` | `openai-codex/config.toml` | `~/.codex/config.toml` | Manual run |
| Direct symlinks | Dotfiles directories | `~/.claude/`, `~/.config/opencode/` etc. | Via install.sh |

### 5.2 Proposed: Unified Config Generator

A single `scripts/generate-configs.py` that:

1. **Reads** `shared/mcp-servers.yaml` and `shared/providers.yaml`
2. **Generates** tool-specific configs:
   - Claude: Updates `mcp-servers.json` with servers targeting `claude`
   - OpenCode: Updates `opencode.json` MCP section with servers targeting `opencode`
   - Codex: Updates `config.toml` MCP and provider sections
   - Agent Deck: Updates `config.toml` MCP section
   - LiteLLM: Generates `config.yaml` from provider registry
3. **Preserves** tool-specific settings (permissions, plugins, agent routing)
4. **Validates** generated configs against schemas where available

### 5.3 Sync Workflow

```
Developer edits shared/mcp-servers.yaml
        |
scripts/generate-configs.py
        |
+--------------------------------------+
| claude/mcp-servers.json     (updated)|
| opencode/opencode.json      (updated)|
| openai-codex/config.toml    (updated)|
| agent-deck/config.toml      (updated)|
| litellm/config.yaml         (updated)|
+--------------------------------------+
        |
install.sh deploys to active locations
        |
sync-codex-config.py deploys Codex config
```

### 5.4 Git Hook Integration

Add a pre-commit hook that runs `generate-configs.py` to catch drift:

```bash
#!/bin/bash
# .git/hooks/pre-commit
python3 scripts/generate-configs.py --check
```

---

## 6. Best Practices and Recommendations

### 6.1 Claude Code

**Current Strengths:**
- Well-structured permissions allow-list
- Comprehensive hook system with audio feedback
- Rich plugin ecosystem
- Agent teams via tmux

**Recommendations:**
1. **Extract hook audio module**: Eliminate ~150 lines of duplication across 5 hooks
2. **Cache ccusage in statusline**: Running `npx ccusage@latest statusline` on every refresh is slow; cache with TTL
3. **Consider hook event matchers**: The Notification hook does keyword matching in Python — could use hook `matcher` field instead for some cases
4. **Review plugin count**: 14 plugins is substantial; evaluate if all are actively used (especially overlapping ones like `search-and-research` vs `mgrep`)
5. **Claude Code Router purpose**: If the router is for cost-saving (routing to Kimi K2 instead of Opus), document this clearly; currently all 3 routes point to the same model

### 6.2 OpenCode

**Current Strengths:**
- Sophisticated multi-model agent routing (oh-my-opencode)
- Greek mythology naming convention for agents is memorable
- Good category-to-model mapping

**Recommendations:**
1. **Add system instructions**: No equivalent of CLAUDE.md — consider adding via oh-my-opencode or opencode native config
2. **Document provider strategy**: Antigravity auth plugin is doing heavy lifting but its routing logic isn't visible in config
3. **Add chrome-devtools MCP**: Currently missing from OpenCode but available in Claude/Codex

### 6.3 OpenAI Codex

**Current Strengths:**
- Clean TOML config
- Profile system for model switching (k2 profile)
- Sync script preserves project trust

**Recommendations:**
1. **Add mgrep MCP**: Available in OpenCode but missing from Codex
2. **Codex sandbox mode**: `workspace-write` is permissive; document the security tradeoff
3. **Enhance sync script**: Could be part of unified generator instead of standalone

### 6.4 Agent Deck

**Current Strengths:**
- Good session management defaults
- MCP pool for server reuse
- Auto-update configured

**Recommendations:**
1. **`dangerous_mode = true`**: Document why and when this is appropriate
2. **Add more MCP servers**: Only has context7; could benefit from chrome-devtools
3. **Configure instances**: Currently empty — could pre-define common session templates

### 6.5 LiteLLM

**Current Strengths:**
- Clean wildcard routing
- Multiple provider support

**Recommendations:**
1. **Remove duplicated Anthropic->OpenRouter proxy**: Routing `anthropic/*` through OpenRouter means Claude Code would use OpenRouter tokens instead of native API — this should be intentional and documented
2. **Align sampling params**: `repetition_penalty: 1.05` only applies to some models; consider per-model defaults
3. **Add health checks**: LiteLLM supports fallback routing — configure failover chains

### 6.6 Cross-Tool Recommendations

1. **Adopt 1Password CLI everywhere**: The `claude-code-router/.env` already uses `op read` — standardize this for all tools
2. **Create a Makefile/justfile**: Replace individual scripts with a unified task runner:
   - `just sync` -> generate all configs + deploy
   - `just mcp-setup` -> register MCP servers
   - `just validate` -> check all configs against schemas
3. **Version pin MCP servers**: `@latest` tags in npx commands can break; pin to specific versions
4. **Cross-tool MCP audit**: Ensure all tools that support a given MCP server have it configured
5. **Document the architecture**: Create a `README.md` in the dotfiles root explaining the tool relationship diagram

### 6.7 Architecture Relationship Diagram

```
+----------------------------------------------------------+
|                    User's Development Environment         |
+----------+----------+----------+----------+--------------+
|  Claude  | OpenCode |  Codex   |  Agent   |   LiteLLM    |
|   Code   |          |   CLI    |   Deck   |   Proxy      |
+----------+----------+----------+----------+--------------+
|                                                           |
|  MCP Layer:  context7 | chrome-devtools | mgrep           |
|                                                           |
+-----------------------------------------------------------+
|                                                           |
|  Provider Layer:                                          |
|    Anthropic (direct) --> Claude Opus/Sonnet/Haiku        |
|    OpenRouter --> Kimi K2, various models                 |
|    Groq --> Fast inference (Kimi K2 Instruct)             |
|    Cerebras --> Fast inference                            |
|    GitHub Copilot --> Claude/GPT via Copilot token        |
|    Google (Antigravity) --> Gemini 3 Pro/Flash            |
|    OpenAI (direct) --> GPT 5 Codex, GPT 5.2              |
|                                                           |
+-----------------------------------------------------------+
|                                                           |
|  Agent Deck orchestrates Claude Code sessions             |
|  LiteLLM proxies requests across providers                |
|  Claude Code Router provides alternative model routing    |
|                                                           |
+-----------------------------------------------------------+
```

### 6.8 Priority Actions

| Priority | Action | Impact | Effort |
|----------|--------|--------|--------|
| **P0** | Extract shared audio module in hooks | Eliminate 150 lines of duplication | Low |
| **P0** | Create `shared/mcp-servers.yaml` | Single source of truth for MCP | Medium |
| **P1** | Build `generate-configs.py` | Automate config sync across tools | Medium |
| **P1** | Standardize API key management via 1Password | Security + consistency | Low |
| **P2** | Cache ccusage in statusline | Performance improvement | Low |
| **P2** | Audit and align MCP servers across all tools | Feature parity | Low |
| **P3** | Create unified justfile for dotfiles management | Developer experience | Medium |
| **P3** | Document architecture in root README | Maintainability | Low |
