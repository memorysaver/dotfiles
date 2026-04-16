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

Pick based on the content's shape, not its emotional tone:

| Section | Use when... |
| ------- | ----------- |
| `steering` | The user redirected the approach ("no, do it the other way"). Capture what was done, what was said, and the underlying rule if inferable. |
| `failed` | Something was tried and did not work. Prefer this over `steering` when there was an actual failure, not just a correction. |
| `worked` | Something worked well enough that it's worth doing again. Include enough context to reproduce. |
| `takeaway` | A durable rule / heuristic you want the future-you to carry. These are the highest-value bullets. |
| `open` | A question the session surfaced but didn't resolve. Open questions are fine to leave open; just don't forget them. |

If a moment plausibly belongs to two sections, pick the one closer to `takeaway` — it's easier to move a misfiled bullet on wrap-up than to invent one from thin air.

## Steps

1. Pick the section (see table above).
2. Write the content as a single short sentence, third-person. Include the concrete detail, not the vibe. ❌ "auth was tricky" → ✅ "JWT rotation failed in dev because the clock skew tolerance was 0 seconds".
3. Run:
   ```bash
   bash "$SKILL_DIR/scripts/append_capture.sh <section> "<content>"
   ```
4. The script finds today's most recently modified `session-*.md` file in `project-memory/lesson-learned/<today>/` and appends `- [HH:MM] <content>` at the bottom of the chosen section (before the next `##` heading). It does not overwrite earlier content.

## Don't

- Don't describe what you are doing to the user before and after every capture — it's noise. Capture, then continue.
- Don't inline quotes that are longer than one line; summarise them.
- Don't capture things you would capture for every session (e.g. "started working", "ran a command"). Those are implied.

## What if there's no active session?

The script exits with an error. Tell the user "no session started yet" and offer to run `start-session` before capturing.
