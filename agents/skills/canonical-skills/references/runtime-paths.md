# Runtime Paths Reference

Where each agent runtime reads project skills, personal skills, and the agent guide. The `canonical-skills` skill enforces the shared project layout; the user-level cells are wired by the dotfiles `just link` loop.

| Runtime | Project skills | Personal skills | Agent guide |
| --- | --- | --- | --- |
| Claude Code | `<project>/.claude/skills` | `~/.claude/skills` | `<project>/CLAUDE.md` (imports `AGENTS.md` via `@AGENTS.md`) |
| Codex | `<project>/.agents/skills` for Codex and agents.md-compatible project-local discovery | `~/.codex/skills` | `<project>/AGENTS.md` |
| Pi Agent | Shared project guide via `<project>/AGENTS.md`; skills are supplied from personal skill links | `~/.pi/agent/skills` | `<project>/AGENTS.md` |

## Why `.claude/skills` and `.agents/skills` both exist

Claude Code reads project skills from `<project>/.claude/skills`. Codex and agents.md-compatible tooling can discover project-local skills from `<project>/.agents/skills`. Both paths must be symlinks to the same real `<project>/skills/` directory so contributors edit one source of truth and git diffs stay honest.

Pi loads skills from its fixed user-home directory and may not merge a project-local skills tree. It still reads `<project>/AGENTS.md`, so the project-level setup supports Pi through the shared guide while the dotfiles `just link` loop supplies the same skill implementations at user level.

## Why both AGENTS.md and CLAUDE.md

`AGENTS.md` is the agents.md-spec file that Codex and Pi Agent (and any other agents.md-compatible tool) read directly. Claude Code reads `CLAUDE.md`, but it supports the `@<file>` import syntax — so a one-line `CLAUDE.md` containing `@AGENTS.md` makes Claude inherit the same guide that Codex and Pi see, with no duplication and no chance of drift.

Edit only `AGENTS.md`. Treat `CLAUDE.md` as a forwarding stub.

## How the personal-skills symlinks are maintained

`~/.dotfiles/Justfile`'s `link` target loops over `~/.dotfiles/agents/skills/*/` and creates three symlinks per skill:

```
~/.claude/skills/<skill>      → ~/.dotfiles/agents/skills/<skill>
~/.codex/skills/<skill>       → ~/.dotfiles/agents/skills/<skill>
~/.pi/agent/skills/<skill>    → ~/.dotfiles/agents/skills/<skill>
```

Re-run `just link` after adding a new skill to the canonical directory, and `just validate-skills` to sanity-check format and linkage. See `~/.dotfiles/agents/skills/README.md` for the full skill-format spec.
