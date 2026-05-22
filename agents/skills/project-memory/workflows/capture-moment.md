# Workflow: capture-moment

Append-only bullets to the active session as notable things happen mid-mission. Cheap, frequent, low-ceremony — capturing early is more valuable than capturing perfectly.

## Trigger

- The user says: "capture this", "note this", "add to lesson", "don't forget this".
- The user corrects you and the correction teaches a durable rule (not just a one-off typo fix).
- The user expresses frustration about the same thing twice.
- Something unexpected works well and is worth reproducing.
- A skill misfires in an instructive way.

When in doubt, capture. Too many bullets is a smaller problem than a lost insight. Wrap-up will consolidate.

## Choosing the section

Pick based on the content's shape, not its emotional tone. The available sections depend on **which sections the file currently has**, not just on `mode`. The original preset (`mode: session` vs `mode: spec`) seeds a different starting set, but `--with-spec-axis` and `promote_to_session.sh` can both add sections later. When in doubt, look at the file — section keys that don't have a matching `## ` heading will be rejected by the append script.

The tables below are organised by typical preset, but section keys are file-driven, not mode-driven:

**`mode: session` — standard template:**

| Section | Use when... |
| ------- | ----------- |
| `steering` | The *user* redirected the approach ("no, do it the other way"). Capture what was done, what was said, and the underlying rule if inferable. |
| `decision` | *You (the agent)* resolved an ambiguity and chose an implementation path. Capture the choice and the reason. |
| `failed` | Something was tried and did not work. Prefer this over `steering` when there was an actual failure, not just a correction. |
| `worked` | Something worked well enough that it's worth doing again. Include enough context to reproduce. |
| `takeaway` | A durable rule / heuristic you want the future-you to carry. These are the highest-value bullets. |
| `open` | A question the session surfaced but didn't resolve. Open questions are fine to leave open; just don't forget them. |

**`mode: spec` — spec-session template (lighter):**

| Section | Use when... |
| ------- | ----------- |
| `decision` | The spec was ambiguous and you picked a path. Capture the choice and the reason. |
| `deviation` | The implementation intentionally departs from the spec. Capture *what* departs and *why*. |
| `tradeoff` | You considered alternatives and rejected them. Capture the rejected option and the reason. |
| `open` | Something for the user to confirm or revise. |

Tiebreaker rules:
- Agent-driven choice → `decision`. User-driven steer → `steering` (session mode only).
- If a moment plausibly belongs to two sections, pick the one closer to `takeaway` (session mode) or `decision` (spec mode) — it's easier to move a misfiled bullet on wrap-up than to invent one from thin air.

## Steps

1. Pick the section (see tables above) — use the table that matches the session's `mode`.
2. Write the content as a single short sentence, third-person. Include the concrete detail, not the vibe. ❌ "auth was tricky" → ✅ "JWT rotation failed in dev because the clock skew tolerance was 0 seconds".
3. Run:
   ```bash
   bash "$SKILL_DIR/scripts/append_capture.sh" <section> "<content>"
   ```
4. The script finds today's most recently modified `session-*.md` file in `project-memory/lesson-learned/<today>/` and appends `- [HH:MM] <content>` at the bottom of the chosen section (before the next `##` heading). It does not overwrite earlier content.

## When `capture_mode: continuous` is set

`mode: spec` sessions get `capture_mode: continuous` by default; `mode: session` sessions can opt in via `--continuous` at start. In continuous mode, the gate for capturing shifts from *notable* to *substantive*:

- Capture every turn that did real work — wrote code, ran a tool, made a decision, surfaced a deviation. Pure clarifying questions and acknowledgements still skip.
- Bias toward `decision` and (in spec mode) `deviation` / `tradeoff`. Reserve `steering` and `failed` for genuine course-changes and failures, not every turn.
- The quality bar is unchanged — one short third-person sentence with the concrete detail. "Continuous" means *more often*, not *less carefully*.
- Capture inline as you work, not at the end of the session. The point is to leave a contemporaneous trail.

In `capture_mode: notable` (the default for `mode: session`), keep the original gate: capture only on steering, frustration, wins, misfires, durable takeaways, and explicit user "capture this" prompts.

## Don't

- Don't describe what you are doing to the user before and after every capture — it's noise. Capture, then continue.
- Don't inline quotes that are longer than one line; summarise them.
- Don't capture things you would capture for every session (e.g. "started working", "ran a command"). Those are implied.

## What if there's no active session?

The script exits with an error. Tell the user "no session started yet" and offer to run `start-session` before capturing.
