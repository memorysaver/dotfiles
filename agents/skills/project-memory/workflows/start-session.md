# Workflow: start-session

Call this at the start of a new mission, once you have a rough one-line description of what the user is trying to accomplish.

## Trigger

- The user says "start a lesson log", "begin a session", "log this mission", or similar.
- The user begins a clearly scoped new task after a prior one ended.
- No session file exists for today yet and the user has started substantive work.

Before calling this, make sure `project-memory/_CONTEXT.md` exists (the umbrella marker). If not, run `bootstrap-memory.md` first.

## Steps

### 1. Pick the mode (capture-shape preset)

`mode` is a **preset**, not a hard partition. Both presets seed from the same data model; they differ in which sections come pre-seeded. Sections can be added later (via `--with-spec-axis` at start or `promote_to_session.sh` mid-session) without rewriting the file's identity.

`start_session.sh` requires `--mode=session` or `--mode=spec`. Decide before invoking it by reading the user's first message about the mission.

**Pick `mode: spec` when *all* of the following are true:**

1. The user has provided (or pointed to) a written specification — PRD, RFC, ADR, design doc, formal feature spec, or similar prescriptive document.
2. The mission is to **implement** that specification, not to debug, refactor, or extend existing code that already implements it.
3. The most valuable thing to record is *how the implementation diverges from or interprets the spec* — not how the conversation evolved.

**Otherwise, pick `mode: session`.** When unsure, pick `session` — it captures a superset of surfaces (steering, what worked, what failed, takeaways, candidates for memory save), so nothing is lost.

**Signals that strongly suggest `spec` mode:**

- The user pasted or linked a spec document and said "implement this" / "build this" / "follow this design".
- The user described the feature in structured, prescriptive language ("must support X", "shall return Y when Z", numbered requirements).
- The user referenced an RFC, ADR, PRD, or "the spec".

**Signals against `spec` mode (even if the user mentioned a spec):**

- The user is asking to *debug* or *refactor* an existing implementation of the spec.
- The "spec" is vague brainstorming or a sketch, not a prescriptive document.
- The mission is exploratory ("let's see what we can do with…", "play with this idea").

### Alternative: session with the spec axis

The gray-zone case — a mission that's part spec-implementation, part refactor/debug of existing code — does not cleanly fit either preset:

- `mode: spec` is too tight (no Steering, no What Worked, no Takeaways).
- `mode: session` has no clean home for `Deviations` / `Tradeoffs` bullets.

Use `mode: session` with `--with-spec-axis` (and optionally `--spec-ref=<pointer>`). The script seeds the full standard template *plus* the three spec-axis sections (Spec Reference, Deviations, Tradeoffs). The `spec_ref` frontmatter field is filled in. The session can run the full Candidates-for-memory-save flow at wrap-up while still capturing spec deviations contemporaneously.

Pick this when condition (1) of the spec-mode rule holds (a spec exists) but condition (2) or (3) fails (mission isn't pure implementation, or the conversation axis is also valuable).

### If drift happens mid-session

If you started in `mode: spec` and the mission morphs into open-ended work (steering, debugging, takeaways start surfacing), don't stuff that into Decisions / Deviations / Tradeoffs. Run:

```bash
bash "$SKILL_DIR/scripts/promote_to_session.sh"
```

…which widens the file to the standard shape, additive only — all existing Decisions / Deviations / Tradeoffs / Open Questions / Links content is preserved verbatim, and the missing standard sections are inserted before Open Questions. Frontmatter `mode` flips to `session`; `capture_mode` and `spec_ref` are preserved. The `_daily.md` row picks up a `(spec→session)` suffix as a historical marker.

Trigger it when:

- The user starts steering you off the spec ("forget that part, do X instead").
- A "what worked" or "what failed" insight is genuinely worth recording but there's no slot.
- A durable rule emerges that you want to flag as a Candidate for memory save.

Don't auto-promote. Announce ("the conversation has widened past the spec — promoting to session mode so we have room for steering and takeaways"), confirm if it's a borderline call, then run the script.

### 2. Decide on `--continuous`

`mode: spec` is always continuous (the script forces it). For `mode: session`, opt in to `--continuous` when the mission is expected to span more than ~30 minutes or ~20 turns, or when the user explicitly wants a contemporaneous trail. Otherwise leave it off — `notable` capture is the default.

### 3. Announce the mode to the user

Before invoking the script, say one short sentence about the chosen mode so the user can correct you cheaply. Examples:

- "Starting in spec mode — I'll keep a running record of decisions, deviations, tradeoffs, and open questions against the spec."
- "Starting a standard session — I'll capture steering, wins, failures, and takeaways as we go."

### 4. Extract the mission

A short imperative phrase (≤10 words): what the user is trying to do, not how. Examples: "refactor auth token rotation", "debug slow CI build", "implement RFC-042 ratelimit".

### 5. Invoke the script

```bash
# Standard or spec preset
bash "$SKILL_DIR/scripts/start_session.sh" --mode=<session|spec> [--continuous] "<mission>"

# Session preset with the spec axis (gray-zone missions)
bash "$SKILL_DIR/scripts/start_session.sh" --mode=session \
     --with-spec-axis [--spec-ref="<pointer>"] [--continuous] "<mission>"
```

Pass the mission as a single argument — quote it. The script prints the session file path on stdout. Capture that path; you'll need it for `capture-moment.md` and `wrap-up-session.md`.

Notes on the flags:

- `--with-spec-axis` adds Spec Reference, Deviations, and Tradeoffs sections to the standard template. Rejected if combined with `--mode=spec` (the spec template already has them).
- `--spec-ref=<value>` populates the `spec_ref` frontmatter field. Implies `--with-spec-axis`.

The script records `agent: other` by default. If you want a specific harness recorded, set `LESSON_AGENT` before invoking:

```bash
LESSON_AGENT=codex bash "$SKILL_DIR/scripts/start_session.sh" --mode=spec "<mission>"
```

### 6. Tell the user how captures work

Mention that the session file exists, that they can just talk normally, and (if applicable) that you're in continuous mode and will capture more aggressively.

## What the script does for you

- Picks today's date (`YYYY-MM-DD`) and the current time (`HHMM`) for the filename.
- Slugifies the mission (lowercase, dashes, ≤40 chars) to form the filename tail.
- Creates the dated folder if missing.
- Seeds `_daily.md` from the daily template on first call of the day.
- Copies the right template based on `--mode`, with frontmatter fields (including `mode`, `capture_mode`, and `spec_ref` placeholder) pre-populated.
- Appends a row to `_daily.md`'s Sessions table with outcome `(in progress)`. Spec-mode sessions get a `(spec)` suffix in the mission column so the daily overview signals them at a glance.

## Avoiding collisions

If a session with the same `HHMM-slug` already exists (rare — you'd have to start two identically-named missions in the same minute), the script suffixes `-2`, `-3`, … so the existing file isn't overwritten.

## After start: fill `spec_ref` immediately (if applicable)

If you chose `mode: spec` (the script leaves `spec_ref` empty), or chose `mode: session --with-spec-axis` without `--spec-ref`, your first task before any other capture is to fill the `spec_ref` frontmatter field with a pointer to the spec — a URL, a file path, or a short title. Future queries depend on this.

## Don't forget

Remember the session file path across the rest of the conversation. Append-only captures during the session all land in that file; wrap-up finalises it.
