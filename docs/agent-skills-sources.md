# Agent Skill Sources

Policy: skills are installed **per project**, not globally. Nothing is symlinked into
`~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or
`~/.gemini/antigravity-cli/skills` any more.

Installer is the Vercel `skills` CLI (pinned below). Every repo in this table was
verified with `npx skills add <repo> --list` on 2026-07-28 against CLI `1.5.20`.

```bash
npx skills@1.5.20 add <repo> --skill <name> -a claude-code -y
npx skills@1.5.20 add <repo> --list          # see what a repo offers first
npx skills@1.5.20 ls --json                  # audit what a project has
```

## Sources

| What you had globally | Install from | Notes |
| --- | --- | --- |
| Your own 11 (`canonical-skills`, `caveman`, `grill-me`, `guizang-ppt-skill`, `nanobana-prompts`, `opencli`, `podwise`, `remotion-best-practices`, `system-thinker`, `wavespeed-cli`, `write-a-skill`) | `memorysaver/dotfiles` | Public repo. All 11 discovered from `agents/skills/`. |
| superpowers (brainstorming, systematic-debugging, TDD, writing-plans, …) | `obra/superpowers` | ~14 skills. Not `obra/superpowers-marketplace` — that resolves but exposes 0 skills. |
| document-skills (`xlsx`, `docx`, `pptx`, `pdf`) | `anthropics/skills` | ~19 skills. |
| obsidian (`defuddle`, `json-canvas`, `obsidian-bases`, `obsidian-cli`, `obsidian-markdown`) | `kepano/obsidian-skills` | **Needs `--full-depth`** — a root `SKILL.md` hides the nested ones otherwise. |
| `agent-browser` | `vercel-labs/agent-browser` | |
| codex (`rescue`, `setup`, runtime helpers) | `openai/codex-plugin-cc` | ~3 skills. |
| `ui-ux-pro-max` | `nextlevelbuilder/ui-ux-pro-max-skill` | **Needs `--full-depth`.** Was an unmanaged real directory. |
| `aep-onboard`, `aep-scaffold` | `memorysaver/agentic-engineering-patterns` | **Needs `--full-depth`.** Marketplace was registered but no plugin enabled. |
| `ichef-context` | `/Users/memorysaver/Documents/github/company-context-layer` | Local path, not a public repo. |

## No replacement available

These came from `claude-plugins-official`, which ships inside Claude Code and has no
public repo to install from. Disabling the plugin removes them with nothing to swap in:

`code-review`, `frontend-design`, `skill-creator`, `code-simplifier`, `ralph-loop`,
`agent-sdk-dev`, `plugin-dev`, `typescript-lsp`

## Caveat: plugin != skill

`npx skills add` copies `SKILL.md` and its bundled files. It does **not** install the
rest of a Claude Code plugin — slash commands, subagents, MCP servers, hooks. So the
`codex` plugin's `codex-rescue` subagent and `agent-browser`'s CLI wiring do not come
across; only the instructional content does.

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

`npx skills experimental_install` restores every entry into `.agents/skills/`. The file
can be hand-authored and `computedHash` may be omitted — the CLI fills it in after
install (verified). Commit it alongside the project.

`sourceType` also accepts `node_modules` (paired with `experimental_sync`) and generic
git, which additionally requires a `sourceUrl` field.

Both commands are `experimental_`-prefixed and absent from the published docs — they
exist only in `--help` and the bundled CLI source. Pin the CLI version.
