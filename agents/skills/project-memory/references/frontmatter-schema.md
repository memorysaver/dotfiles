# Session frontmatter schema

Fields for every `session-<HHMM>-<slug>.md` file. Keep this stable — the scripts parse it.

| Field | Type | Required | Notes |
| ----- | ---- | -------- | ----- |
| `type` | string | yes | Always `lesson`. |
| `mode` | enum | yes | `session` \| `spec`. The **capture-shape preset** originally seeded at start. May widen during the session via `scripts/promote_to_session.sh` (spec → session). Wrap-up reads the *current* value (not the original) to decide whether to run the Candidates-for-memory-save flow. |
| `capture_mode` | enum | yes | `notable` \| `continuous`. Controls how aggressively `capture-moment` records bullets. Defaults to `notable` in `mode: session` and `continuous` in `mode: spec`. Preserved across promote. |
| `date` | string | yes | `YYYY-MM-DD`. |
| `time_started` | string | yes | `HH:MM` (24h). Set at start. |
| `time_ended` | string | no | `HH:MM`. Set during wrap-up. |
| `project` | string | yes | `basename(cwd)` at session start. |
| `mission` | string | yes | One-line summary of what was attempted. |
| `spec_ref` | string | no | Pointer to the spec being implemented (URL, file path, or short title). Populated when started with `--mode=spec`, with `--with-spec-axis` on a `session` start, or after a promote that originated from a spec session. |
| `outcome` | enum | no | `success` \| `partial` \| `failed` \| `abandoned`. Set during wrap-up. |
| `agent` | enum | yes | `claude-code` \| `codex` \| `pi` \| `other`. Set by the script from `$LESSON_AGENT` or default. |
| `model` | string | no | E.g. `claude-opus-4-6`, `gpt-5.5`. Filled during wrap-up from session context. |
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

## Mode values — when to pick each

`mode` is a **capture-shape preset**, not a hard partition of sessions. Both presets seed from the same data model; they just differ in which sections come pre-seeded. Sections can be added later (via `promote_to_session.sh` or `--with-spec-axis`) without changing the file's identity.

- `session` — default. Open-ended task (refactor, debug, design, exploration, extension). The most valuable capture axis is how the *conversation* evolved: user steering, frustrations, wins, durable rules. Seeds the standard 11-section template. Can opt into spec-axis sections with `--with-spec-axis` for gray-zone missions that have a spec component.
- `spec` — the user provided a written specification (PRD, RFC, ADR, design doc) and the mission is to **implement** it. The most valuable capture axis is how the *implementation* relates to the *spec*: decisions, deviations, tradeoffs, open questions. Seeds the lighter spec-session template. If the mission drifts open-ended, run `promote_to_session.sh` to widen.

When unsure, pick `session` — it has a superset of capture surfaces, so nothing is lost. If a session needs the spec axis without a full commitment to spec mode, use `--with-spec-axis`.

The agent picks the preset at session start before invoking `start_session.sh`. Full decision rule lives in [../workflows/start-session.md](../workflows/start-session.md).

## Capture-mode values

- `notable` — default for `mode: session`. `capture-moment` only fires on notable events (steering, frustration, wins, skill misfires, durable takeaways).
- `continuous` — default for `mode: spec`, opt-in via `--continuous` for `mode: session`. `capture-moment` fires on every turn with substantive work. See the "When `capture_mode: continuous` is set" section of [../workflows/capture-moment.md](../workflows/capture-moment.md).

## Agent values

- `claude-code` — Claude Code CLI, desktop, web, or IDE extension.
- `codex` — OpenAI Codex CLI.
- `pi` — Pi agent or Pi coding agent.
- `other` — anything else (opencode, custom agent, etc.).

The bootstrap and start-session scripts respect the `LESSON_AGENT` environment variable if the calling agent wants to override the default.
