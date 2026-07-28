# Agent Skill Sources

## What this repo manages

Two things, and only these:

1. **Config files** for each agent (`agents/*/`), symlinked into place by `just link`.
2. **This list** — the third-party skills we deliberately add, and where to get them.

## What this repo does not manage

Whatever each agent ships with. Those are the vendor's defaults, not ours, and are left
alone. For reference, as of 2026-07-29:

| Agent | Ships with | Where |
| --- | --- | --- |
| Claude Code | ~15 skills (`dataviz`, `artifact-design`, `run`, `init`, `security-review`, …) | compiled into the binary |
| Codex | ~35 skills across 15 `enabled = true` plugins, plus 5 in `~/.codex/skills/.system/` | `agents/codex/config.toml` `[plugins.*]` |
| Antigravity CLI | 3 (`agy-customizations`, `permissioned-github`, `antigravity_guide`) | `~/.gemini/antigravity-cli/builtin/skills` |
| Pi | 0 | — |

Do not prune these to "clean up" global skills. They are how each agent is expected to
work out of the box.

## Policy

Skills are installed **per project**, never into a global skill directory. Nothing is
symlinked into `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or the
Antigravity CLI's directory.

```bash
npx skills@1.5.20 add <repo> --skill <name> -a claude-code -y
npx skills@1.5.20 add <repo> --list          # see what a repo offers first
npx skills@1.5.20 ls --json                  # audit what a project has
```

Each agent has a different project-level skill directory, so let the CLI pick the target
rather than writing paths by hand:

| Agent | Project skill directory |
| --- | --- |
| Claude Code | `<project>/.claude/skills` |
| Codex | `<project>/.agents/skills` |
| Pi | `<project>/.pi/skills` |
| Antigravity CLI | `<project>/.agents/skills` |

## Ours — authored here

These live under `agents/skills/` and install from this public repo. All are discovered
without `--full-depth`.

`canonical-skills` · `nanobana-prompts` · `opencli` · `podwise` ·
`remotion-best-practices` · `system-thinker` · `wavespeed-cli`

```bash
npx skills@1.5.20 add memorysaver/dotfiles --skill <name> -a claude-code -y
```

## Third party — vendored here

Copies that live under `agents/skills/` but originate elsewhere. Kept as copies rather
than list entries for the reason in each row.

| Skill | Upstream | Why still vendored |
| --- | --- | --- |
| `grill-me` (MIT) | `mattpocock/skills` | Upstream is now a two-line stub (`Run a /grilling session.`, `disable-model-invocation: true`) that delegates to a separate `grilling` skill. This copy is the full self-contained version. De-vendoring would be a downgrade, not an update. |
| `guizang-ppt-skill` | `op7418/guizang-ppt-skill` | Still upstream and equivalent — could be de-vendored. |

`caveman` and `write-a-skill` were also vendored from `mattpocock/skills` and were
dropped on 2026-07-29. Both had disappeared upstream — that repo's 42 skills include
neither, and the nearest survivor to the latter is `writing-great-skills`, a different
skill. Recover from git history if they are ever wanted back.

## Third party — install from upstream

| Skill(s) | Repo | Notes |
| --- | --- | --- |
| superpowers (brainstorming, systematic-debugging, TDD, writing-plans, …) | `obra/superpowers` | ~14 skills. Not `obra/superpowers-marketplace` — that resolves but exposes 0. |
| document-skills (`xlsx`, `docx`, `pptx`, `pdf`, …) | `anthropics/skills` | ~19 skills. |
| obsidian (`defuddle`, `json-canvas`, `obsidian-bases`, `obsidian-cli`, `obsidian-markdown`) | `kepano/obsidian-skills` | **Needs `--full-depth`.** |
| `agent-browser` | `vercel-labs/agent-browser` | |
| codex (`rescue`, `setup`, runtime helpers) | `openai/codex-plugin-cc` | ~3 skills. |
| `ui-ux-pro-max` | `nextlevelbuilder/ui-ux-pro-max-skill` | **Needs `--full-depth`.** |
| `aep-onboard`, `aep-scaffold` | `memorysaver/agentic-engineering-patterns` | **Needs `--full-depth`.** |
| `ichef-context` | `/Users/memorysaver/Documents/github/company-context-layer` | Local path, not a public repo. |

`--full-depth` matters whenever a repo has a `SKILL.md` at its root: without it the CLI
stops there and never descends into subdirectories, so nested skills look missing.

Every repo above was verified with `npx skills add <repo> --list` on 2026-07-29 against
CLI `1.5.20`.

### No upstream to install from

`code-review`, `frontend-design`, `skill-creator`, `code-simplifier`, `ralph-loop`,
`agent-sdk-dev`, `plugin-dev`, `typescript-lsp` come from `claude-plugins-official`,
which ships inside Claude Code with no public repo. They stay enabled as plugins in
`agents/claude/settings.json` because there is nothing to install per project in their
place. Note that only `frontend-design` and `skill-creator` actually carry skills — the
rest provide slash commands and subagents.

### Caveat: plugin != skill

`npx skills add` copies `SKILL.md` and its bundled files. It does **not** install the
rest of a Claude Code plugin — slash commands, subagents, MCP servers, hooks. The `codex`
plugin's `codex-rescue` subagent and `agent-browser`'s CLI wiring do not come across;
only the instructional content does.

## Reproducible installs

`skills add` writes `skills-lock.json` at the project root:

```json
{
  "version": 1,
  "skills": {
    "vercel-optimize": {
      "source": "vercel-labs/agent-skills",
      "sourceType": "github",
      "skillPath": "skills/vercel-optimize/SKILL.md",
      "computedHash": "ad0ef9c5…"
    }
  }
}
```

`npx skills experimental_install` restores every entry into `.agents/skills/` — which
Codex and Antigravity read directly, but Claude Code and Pi do not. The file can be
hand-authored and `computedHash` may be omitted; the CLI fills it in after install
(verified). Commit it alongside the project.

`sourceType` also accepts `node_modules` (paired with `experimental_sync`) and generic
git, which additionally requires a `sourceUrl` field.

Both commands are `experimental_`-prefixed and absent from the published docs — they
exist only in `--help` and the bundled CLI source. Pin the CLI version.
