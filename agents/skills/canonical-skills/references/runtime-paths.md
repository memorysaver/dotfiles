# Runtime Paths Reference

Where each agent runtime reads project skills, personal skills, and the agent guide. The `canonical-skills` skill enforces the shared project layout. The user-level column is no longer populated by dotfiles — see below.

| Runtime | Project skills | Personal skills | Agent guide |
| --- | --- | --- | --- |
| Claude Code | `<project>/.claude/skills` | `~/.claude/skills` | `<project>/CLAUDE.md` (imports `AGENTS.md` via `@AGENTS.md`) |
| Codex | `<project>/.agents/skills` for Codex and agents.md-compatible project-local discovery | `~/.codex/skills` | `<project>/AGENTS.md` |
| Pi Agent | `<project>/.pi/skills` | `~/.pi/agent/skills` | `<project>/AGENTS.md` |

## Why `.claude/skills` and `.agents/skills` both exist

Claude Code reads project skills from `<project>/.claude/skills`. Codex and agents.md-compatible tooling can discover project-local skills from `<project>/.agents/skills`. Both paths must be symlinks to the same real `<project>/skills/` directory so contributors edit one source of truth and git diffs stay honest.

Pi reads project skills from `<project>/.pi/skills` and adds any extra paths listed in the `skills` array of `~/.pi/agent/settings.json`. It also reads `<project>/AGENTS.md`, so the shared guide reaches Pi the same way it reaches Codex.

## Why both AGENTS.md and CLAUDE.md

`AGENTS.md` is the agents.md-spec file that Codex and Pi Agent (and any other agents.md-compatible tool) read directly. Claude Code reads `CLAUDE.md`, but it supports the `@<file>` import syntax — so a one-line `CLAUDE.md` containing `@AGENTS.md` makes Claude inherit the same guide that Codex and Pi see, with no duplication and no chance of drift.

Edit only `AGENTS.md`. Treat `CLAUDE.md` as a forwarding stub.

## Personal skills are no longer installed globally

The dotfiles `link` target used to symlink every skill under `~/.dotfiles/agents/skills/`
into each runtime's user-level directory. That loop was removed on 2026-07-28; skills are
installed per project instead:

```bash
npx skills@1.5.20 add memorysaver/dotfiles --skill <name> -a claude-code -a codex -a pi -y
```

The user-level column in the table above therefore holds only whatever each runtime or a
third-party integration puts there directly. Run `just validate-skills` after editing a
canonical skill to sanity-check its format. See `~/.dotfiles/agents/skills/README.md` for
the full skill-format spec and `~/.dotfiles/docs/agent-skills-sources.md` for install
sources.
