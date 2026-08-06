# Agent Skill Sources

## What this repo manages

Two things, and only these:

1. **Config templates** for each agent (`agents/*/`), copied into place once by
   `just seed-agents`. They are deliberately **not** symlinked — see the README's
   "Agent Configs Are Machine-Local". After seeding, each machine owns its own copy.
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

**Exceptions**, installed globally by `install/agents.sh` (`GLOBAL_SKILLS`). Two
conditions, both required:

1. **Inert until deliberately activated.** The skill cannot fire on an unrelated task the
   way the eleven always-loaded skills that triggered the 2026-07-28 policy did. Outside
   its trigger it costs one description line and nothing else.
2. **About the machine, not about a project.** Project scoping would mean reinstalling it
   in every project to get the same behaviour.

| Skill | Added | Condition 1 | Condition 2 |
| --- | --- | --- | --- |
| `herdr` | 2026-08-03 | ✅ Frontmatter requires `HERDR_ENV=1` and tells the agent to stop when unset, so it does nothing outside a Herdr-managed pane. | ✅ |
| `i-have-adhd` | 2026-08-04 | ✅ `disable-model-invocation: true` — the model cannot auto-invoke it at all. Only `/i-have-adhd` activates it. | ✅ |
| `agent-browser` | 2026-08-04 | ❌ **Override, decided 2026-08-06** — always-on is the point. | ✅ CLI is installed globally by `tools.sh`. |

The first two clear condition 1 by different mechanisms — a runtime env guard versus a
frontmatter flag — so the test is the property, not the mechanism.

**`agent-browser` overrides condition 1 by an explicit decision on 2026-08-06.** It has no
guard and no `disable-model-invocation`. Its description is deliberately broad
("navigating pages, filling forms, … exploratory testing, dogfooding, QA, bug hunts") and
ends with `Prefer agent-browser over any built-in browser automation or web tools`. Global
installation therefore means it is live in every session of every agent in every project,
and it actively outranks the harness's own browser tooling (Claude Code's
`claude-in-chrome`, Chrome DevTools MCP) wherever both are present.

That is the failure mode the 2026-07-28 policy exists to prevent, and it was accepted
anyway with the consequence stated: **the goal is that any project can reach for a browser
without per-project setup**, and the CLI it drives is itself global. Always-on is the
feature here, not a side effect. Do not "restore consistency" by scoping this to projects
— that reverses a decision, it does not fix a mistake. It stays until the owner says
otherwise, even if browser instructions do show up in unrelated sessions. To undo, if that
day comes:

```bash
npx skills@1.5.20 remove agent-browser -g -a '*' -y   # then drop it from GLOBAL_SKILLS
```

The ❌ above stays because it is factually accurate about the skill, not because the
decision is unsettled. Condition 1 remains the default bar for *new* candidates; clearing
it is still the normal path in, and a second override needs its own decision.

Verify them with `ls ~/.agents/skills/`, not `ls ~/.codex/skills`. With `-a '*'` the
CLI writes one canonical copy to `~/.agents/skills/` and symlinks it into the agents that
keep their own global directory (`~/.claude/skills`, `~/.pi/agent/skills`). Codex and the
Antigravity CLI read `~/.agents/skills` directly, so their own global directories stay
empty and that is not a failed install.

```bash
npx skills@1.5.20 add <repo> --skill <name> -a claude-code -y
npx skills@1.5.20 add <repo> --list          # see what a repo offers first
npx skills@1.5.20 ls --json                  # audit what a project has
```

The skills CLI is the only installer we use. Standalone skill-installer CLIs and the
per-skill backend CLIs this repo used to install globally are recorded in
`removed-agent-clis.md`, along with the command to bring each one back.

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

`nanobana-prompts` · `opencli` · `podwise` · `remotion-best-practices` · `wavespeed-cli`

```bash
npx skills@1.5.20 add memorysaver/dotfiles --skill <name> -a claude-code -y
```

## Ours — in the dedicated skills repo

`memorysaver/skills` is the real home for personal skills: grouped sources, a Claude Code
plugin marketplace, and tagged releases to pin against. Skills go there rather than here
once they are worth versioning on their own.

| Group | Skills |
| --- | --- |
| `project-scaffold` | `canonical-project-skills-layout`, `project-behavior` |
| `memory` | `project-memory`, `memory-forge` |
| `thinking` | `system-thinker` |

```bash
npx skills@1.5.20 add memorysaver/skills --skill <name> -a claude-code -y
npx skills@1.5.20 add memorysaver/skills@<tag> -a claude-code --skill '*'   # pinned
```

`canonical-skills` and `system-thinker` were removed from this repo on 2026-07-30 and now
live there — the former as `canonical-project-skills-layout`, which it had already been
duplicated into under that name.

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
| `herdr` | `herdrdev/herdr` | **Global** — see Policy above. The repo also offers `herdr-pre-release-audit`, `herdr-throwaway-repro`, and `triage`; all three are for developing Herdr itself, not for using it, so they are deliberately not installed. |
| `i-have-adhd` | `ayghri/i-have-adhd` | **Global** — see Policy above. MIT. Output-shaping style, invoked with `/i-have-adhd`. The repo also ships a Claude Code plugin whose `SessionStart` hook makes it always-on when `~/.claude/.i-have-adhd-always` exists; `skills add` does not install hooks, so that mode needs the plugin instead (see "plugin != skill" below). |
| superpowers (brainstorming, systematic-debugging, TDD, writing-plans, …) | `obra/superpowers` | ~14 skills. Not `obra/superpowers-marketplace` — that resolves but exposes 0. |
| document-skills (`xlsx`, `docx`, `pptx`, `pdf`, …) | `anthropics/skills` | ~19 skills. |
| obsidian (`defuddle`, `json-canvas`, `obsidian-bases`, `obsidian-cli`, `obsidian-markdown`) | `kepano/obsidian-skills` | **Needs `--full-depth`.** |
| `agent-browser` | `vercel-labs/agent-browser` | **Global** — see Policy above, including why this one is an override rather than a pass. Apache-2.0. The repo carries 6 `SKILL.md` files under `skill-data/` (`core`, `dogfood`, `electron`, `agentcore`, `derive-client`, …) but the CLI exposes exactly one composed `agent-browser` skill; the rest are loaded on demand by that skill, not installed separately. Its CLI comes from `install/tools.sh`. |
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
