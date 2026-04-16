---
name: project-memory
description: "Use when the user wants to capture, organize, or retrieve project knowledge as a git-committable memory system at project-memory/ at the project root. Trigger proactively on phrases: 'lesson learned', 'save lesson', 'wrap up session', 'postmortem', 'retro', 'capture this', 'what did we learn', 'why did this fail', 'have we seen this before', 'add to lesson', 'end of session', 'project memory', 'team memory'. Also trigger when a mission is ending and no lesson has been captured yet, or when the user asks a question whose answer likely lives in prior work. Backed by qmd for hybrid BM25 + vector search over every subsystem under project-memory/."
version: 0.1.0
metadata:
  clawdbot:
    emoji: "🧠"
---

# project-memory

An umbrella memory system for a project. Lives at `project-memory/` at the project root so teammates see it immediately, and is committed to git so the memory travels with the code.

Today the only subsystem is `project-memory/lesson-learned/` (per-session retrospectives). Future subsystems — decisions, glossaries, onboarding notes, whatever — land as sibling folders under `project-memory/` and are auto-indexed by the same qmd collection.

## Entry points — pick one and load that workflow

- **First time in a project** → [workflows/bootstrap-memory.md](workflows/bootstrap-memory.md). Check for `project-memory/_CONTEXT.md`; if missing, bootstrap before anything else.
- **Starting a new mission** → [workflows/start-session.md](workflows/start-session.md).
- **Mid-session notable moment** (steering, frustration, win, takeaway) → [workflows/capture-moment.md](workflows/capture-moment.md).
- **Mission ending** → [workflows/wrap-up-session.md](workflows/wrap-up-session.md).
- **User asks about prior work** ("have we seen this", "what did we learn about X") → [workflows/query-memory.md](workflows/query-memory.md).

## Why this skill exists

Sessions produce valuable signal that gets lost the moment the chat closes: which prompts the user had to rewrite, which skills misfired, which frustration patterns repeat. A flat log captures that but can't be retrieved later. Tying capture to a qmd-backed index lets a future session semantically recall "we tried X for auth refactors last month and it failed because Y" without grepping blindly. Promoting the folder to `project-memory/` at the project root also signals to teammates that this is a first-class knowledge surface — they can skim, contribute, and query it too.

## File layout in every project

```
project-memory/
├── .gitignore                       # umbrella — ignores qmd sidecars (committed)
├── _CONTEXT.md                      # umbrella — qmd collection description (committed)
└── lesson-learned/                  # current subsystem
    ├── _INDEX.md                    # curated catalog, human-skimmable (committed)
    └── 2026-04-16/
        ├── _daily.md                # overview of the day's sessions
        ├── session-0915-refactor-auth.md
        └── session-1330-debug-build.md
```

`_INDEX.md` is subsystem-scoped because its content (Running Themes, Session Log) only makes sense for lessons. Future subsystems will have their own catalog shape. `.gitignore` and `_CONTEXT.md` live at the umbrella because they describe the whole qmd collection.

## qmd integration

One qmd collection per project, name = `<basename(cwd)>-memory`. It is scoped to the entire `project-memory/` umbrella with pattern `**/*.md`, so **every subsystem under `project-memory/` is indexed by the same collection** — adding a new subsystem later requires no new qmd registration. Managed by `scripts/bootstrap_memory.sh` (register) and `scripts/qmd_update.sh` (re-index). Query anytime:

```bash
qmd query "<natural question>" -c "$(basename $PWD)-memory"
qmd search "<keywords>"        -c "$(basename $PWD)-memory"
```

If `qmd` is not installed, every read surface falls back to `rg`. Writes never depend on qmd. Full detail in [references/qmd-integration.md](references/qmd-integration.md).

## Bundled scripts

Always prefer running `scripts/*.sh` over re-deriving the mechanics inline. The scripts encode slug generation, timestamp formatting, idempotent folder creation, section-aware inserts, and qmd calls. Each workflow file above calls out the exact script to invoke.

Scripts live under the skill itself. Invoke them via the absolute path to wherever the skill is installed (e.g. `~/.claude/skills/project-memory/scripts/<name>.sh` for Claude Code, `~/.codex/skills/project-memory/scripts/<name>.sh` for Codex — both symlink to the same source in the dotfiles repo).

## Cross-agent note

This skill runs identically under Claude Code and Codex because everything important is done by shell scripts and tool-agnostic markdown edits. The one agent-specific detail is the `agent:` frontmatter field — set `LESSON_AGENT=codex` in the environment before invoking the scripts from Codex, otherwise they default to `claude-code`.

## References (load only when needed)

- [references/template-session.md](references/template-session.md) — canonical session file template. Read when running `start-session` or `wrap-up-session`.
- [references/template-daily.md](references/template-daily.md), [references/template-index.md](references/template-index.md), [references/template-context.md](references/template-context.md) — seed templates, consumed by the scripts.
- [references/frontmatter-schema.md](references/frontmatter-schema.md) — field definitions and allowed values. Read when editing frontmatter.
- [references/qmd-integration.md](references/qmd-integration.md) — qmd command reference + fallback behaviour. Read before any qmd invocation.

## Don't

- Don't auto-save approved "Candidates for memory save" — those go to `~/.claude/projects/.../memory/` only after the user explicitly confirms.
- Don't promote lessons into an Obsidian vault — project memory is project-scoped by design.
- Don't overwrite captured content; the capture script is append-only for a reason.
