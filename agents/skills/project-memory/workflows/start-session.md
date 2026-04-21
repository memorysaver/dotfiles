# Workflow: start-session

Call this at the start of a new mission, once you have a rough one-line description of what the user is trying to accomplish.

## Trigger

- The user says "start a lesson log", "begin a session", "log this mission", or similar.
- The user begins a clearly scoped new task after a prior one ended.
- No session file exists for today yet and the user has started substantive work.

Before calling this, make sure `project-memory/_CONTEXT.md` exists (the umbrella marker). If not, run `bootstrap-memory.md` first.

## Steps

1. Extract the mission as a short imperative phrase (≤10 words): what the user is trying to do, not how. Examples: "refactor auth token rotation", "debug slow CI build", "design project-memory skill".
2. Run:
   ```bash
   bash "$SKILL_DIR/scripts/start_session.sh" "<mission>"
   ```
   Pass the mission as a single argument — quote it.
3. The script prints the session file path on stdout. Capture that path; you'll need it for `capture-moment.md` and `wrap-up-session.md`.
4. The script records `agent: other` by default. If you want a specific harness recorded, set `LESSON_AGENT` before invoking:
   ```bash
   LESSON_AGENT=codex bash "$SKILL_DIR/scripts/start_session.sh" "<mission>"
   ```
5. Tell the user the session file exists and briefly remind them how captures work (they can just talk normally; you'll append to the right section automatically).

## What the script does for you

- Picks today's date (`YYYY-MM-DD`) and the current time (`HHMM`) for the filename.
- Slugifies the mission (lowercase, dashes, ≤40 chars) to form the filename tail.
- Creates the dated folder if missing.
- Seeds `_daily.md` from the daily template on first call of the day.
- Copies the session template with frontmatter fields pre-populated.
- Appends a row to `_daily.md`'s Sessions table with outcome `(in progress)`.

## Avoiding collisions

If a session with the same `HHMM-slug` already exists (rare — you'd have to start two identically-named missions in the same minute), the script suffixes `-2`, `-3`, … so the existing file isn't overwritten.

## Don't forget

Remember the session file path across the rest of the conversation. Append-only captures during the session all land in that file; wrap-up finalises it.
