# Canonical Agent Skills

This directory is the canonical source for personal agent skills. Each child
directory is a portable Agent Skill built around a `SKILL.md` file plus optional
relative `workflows/`, `references/`, `scripts/`, `assets/`, and `evals/`
folders.

The same skill directories are exposed to each agent by symlink:

| Agent | Install path | Source of truth |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<skill>` | `~/.dotfiles/agents/skills/<skill>` |
| Codex | `~/.codex/skills/<skill>` | `~/.dotfiles/agents/skills/<skill>` |
| Pi Agent | `~/.pi/agent/skills/<skill>` | `~/.dotfiles/agents/skills/<skill>` |

Do not edit the symlinked copies. Edit the skill directory here, then run:

```bash
just link
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
| `nanobana-prompts` | Supported | Supported | Supported | None |
| `opencli` | Supported | Supported | Supported | Node.js 20+, `@jackwener/opencli` |
| `podwise` | Supported | Supported | Supported | Podwise CLI and API key |
| `project-memory` | Supported | Supported | Supported | Optional `qmd`; falls back to text search |
| `remotion-best-practices` | Supported | Supported | Supported | Remotion project dependencies as applicable |
| `wavespeed-cli` | Supported | Supported | Supported | WaveSpeed CLI and `WAVESPEED_API_KEY` |

## Local Agent Configuration

Claude Code discovers skills from `~/.claude/skills`.

Codex discovers personal skills from `~/.codex/skills`; system and plugin skills
can coexist in the same parent directory.

Pi Agent is configured by `~/.pi/agent/settings.json`, which should include:

```json
{
  "skills": [
    "~/.pi/agent/skills"
  ],
  "enableSkillCommands": true
}
```

## Maintenance Checklist

1. Add or edit the canonical skill under this directory.
2. Run `just link` to refresh symlinks through the dotfiles installer.
3. Run `just validate-skills` to check portability and installed links.
4. Commit only canonical skill changes and support scripts, not generated copies.
