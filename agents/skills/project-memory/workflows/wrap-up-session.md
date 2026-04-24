# Workflow: wrap-up-session

Call this when a mission is ending — whether it succeeded, partially worked, failed, or got abandoned. The capture is valuable in all four cases. Abandoned missions often teach the most.

## Trigger

- The user says: "wrap up the lesson", "end of session", "save the postmortem", "write the retro".
- A mission clearly ended (outcome known, conversation shifts topics). If no wrap-up has happened, offer one before moving on.
- The user is about to close the chat / switch contexts.

Don't wait to be asked every single time — offering a wrap-up at a natural end-point is part of the job.

## Steps

### 1. Fill every section of the session file

Read the current session file (its path was returned by `start-session`). The file is mostly empty scaffolding + whatever bullets `capture-moment` added. Your job here is to fill every section using the full conversation as the source of truth:

- **Mission** — one paragraph. What the user set out to do, in context.
- **Prompt Evolution** — numbered list. Each turn where the user changed direction gets a one-line summary of the new prompt and a one-line "why it shifted" note. Skip turns where the user only acknowledged or answered a minor clarification.
- **Steering & Course Corrections** — keep captured bullets; add any you noticed that weren't captured mid-session.
- **What Worked** — concrete wins, with enough detail to reproduce.
- **What Failed / Frustrations** — failures and their root cause if knowable. If the root cause is still unclear, write "unclear — suspect X" rather than inventing one.
- **Skills & Tools Involved** — table. One row per skill/tool actually used. Columns: Name, Role, Quality (worked / mixed / misfired), Quirks. Be honest about misfires — this is where future sessions learn to avoid bad paths.
- **Takeaways** — the point of the whole file. Concrete rules the next session should carry. Prefer testable ("if X, do Y because Z") over vibes ("be careful with auth").
- **Candidates for memory save** — draft memory entries the user should consider promoting to `~/.claude/projects/.../memory/`. Format each one with full frontmatter so the user can copy-paste approve:
  ```
  - type: feedback
    name: integration_tests_real_db
    body: "Integration tests must hit a real database, not mocks.
           Why: ...
           How to apply: ..."
  ```
  Only propose candidates that are genuinely durable rules. If the session didn't surface one, say so — empty is better than noise.
- **Open Questions** — leave these open; don't answer them speculatively.
- **Links** — if there are related prior sessions, link them as `[[YYYY-MM-DD/session-HHMM-slug]]`.

### 2. Update frontmatter

Edit the frontmatter in-place:

- `time_ended` — current `HH:MM`.
- `outcome` — `success` | `partial` | `failed` | `abandoned`. When unsure, pick `partial`; overclaiming `success` poisons the index.
- `model` — the model powering this session (e.g. `claude-opus-4-6`, `gpt-5.5`).
- `skills_used`, `tools_used`, `tags` — fill with the actual names.

### 3. Update the indexes

```bash
bash "$SKILL_DIR/scripts/update_index.sh" "<session-file-path>"
```

The script:
- Rewrites the row for this session in `_daily.md` (outcome column).
- Appends a row to `_INDEX.md`'s Session Log with the date, session, mission, outcome, and the first takeaway bullet.

### 4. Refresh the qmd index

```bash
bash "$SKILL_DIR/scripts/qmd_update.sh"
```

Fast no-op if nothing changed; safe no-op if qmd is not installed.

### 5. Report back to the user

Print, concisely:
- The session file path (so they can open it).
- The outcome.
- Any "Candidates for memory save" you drafted, with a clear question: "Want me to save any of these as memory?" (Don't auto-save.)
- A reminder to `git add project-memory/lesson-learned/<date>/ && git commit` when convenient.

## Curating Running Themes (optional)

If this session shares an obvious pattern with ≥1 prior session (same mistake recurring, same approach repeatedly working), manually update the `## Running Themes` section of `_INDEX.md` with a new entry or an updated one. This is hand-curation — don't automate it. Running Themes are the most useful part of the index for humans; keep them tight.

## What if the session was trivial?

If a mission was so small that wrap-up feels like ceremony, say so and ask the user if they'd rather skip the full template and just write a one-paragraph summary in the session file's Takeaways. Skipping is better than performative filler.
