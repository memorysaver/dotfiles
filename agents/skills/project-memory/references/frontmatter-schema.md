# Session frontmatter schema

Fields for every `session-<HHMM>-<slug>.md` file. Keep this stable — the scripts parse it.

| Field | Type | Required | Notes |
| ----- | ---- | -------- | ----- |
| `type` | string | yes | Always `lesson`. |
| `date` | string | yes | `YYYY-MM-DD`. |
| `time_started` | string | yes | `HH:MM` (24h). Set at start. |
| `time_ended` | string | no | `HH:MM`. Set during wrap-up. |
| `project` | string | yes | `basename(cwd)` at session start. |
| `mission` | string | yes | One-line summary of what was attempted. |
| `outcome` | enum | no | `success` \| `partial` \| `failed` \| `abandoned`. Set during wrap-up. |
| `agent` | enum | yes | `claude-code` \| `codex` \| `pi` \| `other`. Set by the script from `$LESSON_AGENT` or default. |
| `model` | string | no | E.g. `claude-opus-4-6`, `gpt-5.4`. Filled during wrap-up from session context. |
| `skills_used` | list[string] | no | Skill names invoked during the session. |
| `tools_used` | list[string] | no | Non-skill tooling worth remembering (CLIs, MCP servers). |
| `tags` | list[string] | no | Short topical tags (e.g. `auth`, `refactor`, `migration`). |
| `related_sessions` | list[string] | no | Wikilinks to other sessions: `[[YYYY-MM-DD/session-HHMM-slug]]`. |

## Outcome values — when to pick each

- `success` — the mission's goal was met, verified.
- `partial` — progress made, but the user paused or scope narrowed.
- `failed` — the attempt finished with the goal not met.
- `abandoned` — the mission was dropped (pivoted, deprioritised, etc.) before a real result.

Pick `partial` over `success` when in doubt; overclaiming success poisons the index.

## Agent values

- `claude-code` — Claude Code CLI, desktop, web, or IDE extension.
- `codex` — OpenAI Codex CLI.
- `pi` — Pi agent or Pi coding agent.
- `other` — anything else (opencode, custom agent, etc.).

The bootstrap and start-session scripts respect the `LESSON_AGENT` environment variable if the calling agent wants to override the default.
