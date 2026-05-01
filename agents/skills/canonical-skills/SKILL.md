---
name: canonical-skills
description: Use when setting up a new project, auditing an existing one, or aligning a project so the same project-level skills and agent guide work under Claude Code, Codex, and Pi Agent. Trigger on phrases like "make this project canonical", "set up canonical skills layout", "ensure canonical skills style", "migrate CLAUDE.md to AGENTS.md", "make claude/codex/pi share the same agent guide here", "standardize the agent layout for this repo", or whenever the user opens a fresh project and wants the five project invariants (skills/ real dir, .claude/skills symlink, .agents/skills symlink, AGENTS.md canonical, CLAUDE.md = @AGENTS.md) to hold. Also trigger when the user mentions only one of these symptoms (drifted CLAUDE.md vs AGENTS.md, .claude/skills or .agents/skills as a real directory, multiple skills directories) — the goal is to converge to the canonical shape every time, not just react to the symptom they named.
license: Apache-2.0
version: 0.1.0
---

# canonical-skills

Apply a single, predictable layout to any project the user works in so Claude Code, Codex, and Pi Agent share one project guide and one project skill source of truth wherever the runtime supports project-local skills. The skill is installed once at the user level (via the dotfiles `just link` symlink loop) and shows up automatically inside every user-level runtime.

## The five invariants

| What | Where | Why it has to be this exact shape |
| --- | --- | --- |
| Project skills source of truth | `<project>/skills/` (real directory) | One canonical place to add, edit, and review skills. Tracked in git as itself, not as an alias. |
| Claude Code project skills | `<project>/.claude/skills` → symlink to `../skills` | Claude Code reads project skills from this exact path. Pointing it at the canonical dir avoids dual-write and keeps git diffs honest. |
| Codex project skills | `<project>/.agents/skills` → symlink to `../skills` | Codex and agents.md-style tooling can discover project-local skills from `.agents/skills` while sharing the same canonical `skills/` source. |
| Canonical agent guide | `<project>/AGENTS.md` (real file) | Read by Codex, Pi Agent, and any agents.md-spec compatible tool. This is the single editable source. |
| Claude Code agent guide | `<project>/CLAUDE.md` containing exactly `@AGENTS.md` | Claude Code follows the `@import` syntax to load AGENTS.md. Keeping CLAUDE.md as a one-line import means there's only one place to edit guidance — AGENTS.md — and Claude inherits everything Codex/Pi see. |

Codex and Pi still read personal skills from fixed user-home locations, but this project layout gives all three runtimes the same guide and keeps project-local skill files in the standard discovery paths that support them. See [references/runtime-paths.md](references/runtime-paths.md) for the full per-runtime path table.

## When to invoke

- New project: right after `git init` or `git clone`, before adding any project-specific skills or agent guidance.
- Auditing an existing project: when you suspect drift — symptoms include `.claude/skills` or `.agents/skills` containing real directories instead of being symlinks, both `CLAUDE.md` and `AGENTS.md` existing with different content, or skills appearing under more than one path.
- Migrating from Claude-only to multi-runtime: when a project that started life with just `CLAUDE.md` needs to also work cleanly under Codex/Pi.

If the project genuinely has no agent guide and no project-level skills (e.g. a repo that only ever runs in Claude Code with the user's global skills), this skill is still safe to run — it'll just create the canonical shells and exit, no destructive moves.

## How to apply

The skill bundles a single idempotent script. It's safe to run repeatedly; the no-op path is the same as the migration path when there's nothing to migrate.

```bash
# 1. Always preview first
bash "$SKILL_DIR/scripts/ensure-canonical-skills.sh" --dry-run [path]

# 2. Review the planned actions, then commit
bash "$SKILL_DIR/scripts/ensure-canonical-skills.sh" [path]
```

`$SKILL_DIR` is the directory containing this SKILL.md — under any user-level runtime the skill's installed dir is a symlink to `~/.dotfiles/agents/skills/canonical-skills/`, so the script is the same one regardless of which runtime invokes it. The path argument defaults to the current working directory.

The script prints one line per action it would take or has taken, plus a final `migration complete` / `already canonical` line. Re-running on a fully canonical project produces only the latter.

## What the script will and won't auto-fix

It will:

- Create `<project>/skills/` if missing.
- Add `<project>/skills/.gitkeep` when initializing an otherwise empty project skills directory, so the canonical directory survives git checkouts before the project has real skills.
- Convert `<project>/.claude/skills` from a real directory into a symlink, moving any existing entries into `<project>/skills/` first. Tracked entries move via `git mv` so history follows; in-tree redundant symlinks (e.g. `.claude/skills/X → ../../skills/X`) are dropped instead of moved.
- Convert `<project>/.agents/skills` from a real directory into a symlink, moving any existing entries into `<project>/skills/` first. Tracked entries move via `git mv` so history follows; in-tree redundant symlinks are dropped instead of moved.
- Copy `CLAUDE.md` → `AGENTS.md` and replace `CLAUDE.md` with the one-line `@AGENTS.md` import, in the cases where this is unambiguous.

It will refuse and ask for manual resolution when:

- `<project>/skills` is itself a symlink pointing somewhere else — likely intentional, the script can't guess where.
- An entry inside `.claude/skills/` or `.agents/skills/` would collide with an existing entry in `skills/` that has different content.
- Both `CLAUDE.md` and `AGENTS.md` exist with **different** real content. The script prints a `diff --stat` hint; merge into `AGENTS.md` by hand, then re-run. (Refusal is per-step, not per-project — other steps still progress.)
- The project has uncommitted changes (the migration should be one reviewable diff, not a mix).

## AGENTS.md / CLAUDE.md decision table

The script picks an action by reading both files. `@AGENTS.md` here means a `CLAUDE.md` whose first non-empty line is exactly the literal string `@AGENTS.md` and which is short enough to plausibly contain only that import.

| `CLAUDE.md` | `AGENTS.md` | Action |
| --- | --- | --- |
| absent | absent | no-op |
| `@AGENTS.md` import | present | already canonical, no-op |
| absent | present | create `CLAUDE.md` containing `@AGENTS.md\n` |
| present (real content) | absent | move `CLAUDE.md` → `AGENTS.md`, then write `CLAUDE.md` = `@AGENTS.md\n` |
| present (real content) | present, byte-identical | overwrite `CLAUDE.md` = `@AGENTS.md\n` |
| present (real content) | present, divergent | **REFUSE.** Print diff hint, skip this step, continue with the rest. |

## Runtime notes

**Claude Code** reads project skills from `<project>/.claude/skills` and reads `<project>/CLAUDE.md`, following the `@AGENTS.md` import to load the canonical guide.

**Codex** and **Pi Agent** both read `<project>/AGENTS.md` directly per the agents.md spec. Codex and Pi source personal skills from their respective user-home locations (see [references/runtime-paths.md](references/runtime-paths.md)); Codex and agents.md-compatible workflows can additionally discover project-local skills through `<project>/.agents/skills`.

## Cross-reference

For older AEP downstreams that still need broader repo migration behavior, see `~/Documents/github/agentic-engineering-patterns/scripts/migrate-downstream-layout.sh`. The canonical invariant here keeps both `.claude/skills` and `.agents/skills` symlinked to a shared `skills/` directory, so use this skill for any project whether it is Claude Code-first, Codex-first, Pi-first, or shared across all three.
