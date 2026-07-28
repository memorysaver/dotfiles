# Canonical Agent Skills

This directory is the canonical source for personal agent skills. Each child
directory is a portable Agent Skill built around a `SKILL.md` file plus optional
relative `workflows/`, `references/`, `scripts/`, `assets/`, and `evals/`
folders.

These skills are **not installed globally**. As of 2026-07-28 the installer no longer
symlinks them into `~/.claude/skills`, `~/.codex/skills`, `~/.pi/agent/skills`, or
`~/.gemini/antigravity-cli/skills`. Install them per project instead:

```bash
npx skills@1.5.20 add memorysaver/dotfiles --list            # see what is here
npx skills@1.5.20 add memorysaver/dotfiles --skill system-thinker -a claude-code -y
```

This repo is public, and all skills here are discoverable by the CLI without
`--full-depth`. See `docs/agent-skills-sources.md` for every other skill source and for
the `skills-lock.json` format that makes a project's set reproducible.

Edit the skill here, then run:

```bash
just validate-skills
```

## Skill Format

Every canonical skill must include `SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: Short trigger and purpose description.
license: Apache-2.0
version: 0.1.0
---
```

Required fields are `name` and `description`. Recommended optional fields are
`license`, `version`, `homepage`, `compatibility`, and `metadata`.

Keep the body agent-neutral. If a skill must mention a runtime-specific behavior,
put it under a short section such as `## Claude Code Notes`, `## Codex Notes`, or
`## Pi Agent Notes`.

## Current Support Matrix

| Skill | Claude Code | Codex | Pi Agent | Runtime dependencies |
| --- | --- | --- | --- | --- |
| `canonical-skills` | Supported | Supported | Supported | Bash, `git` (optional but recommended) |
| `grill-me` | Supported | Supported | Supported | None |
| `guizang-ppt-skill` | Supported | Supported | Supported | None |
| `nanobana-prompts` | Supported | Supported | Supported | None |
| `opencli` | Supported | Supported | Supported | Node.js 20+, `@jackwener/opencli` |
| `podwise` | Supported | Supported | Supported | Podwise CLI and API key |
| `remotion-best-practices` | Supported | Supported | Supported | Remotion project dependencies as applicable |
| `system-thinker` | Supported | Supported | Supported | None |
| `wavespeed-cli` | Supported | Supported | Supported | WaveSpeed CLI and `WAVESPEED_API_KEY` |

## Maintenance Checklist

1. Add or edit the canonical skill under this directory.
2. Run `just validate-skills` to check frontmatter, relative links, and portability.
3. Commit the change and push, so projects can install the new version.
4. In each project that needs it, run `npx skills add memorysaver/dotfiles --skill <name>`
   (or `npx skills update <name>` to pull a newer version).
