# Workflow: wrap-up-session

Call this when a mission is ending — whether it succeeded, partially worked, failed, or got abandoned. The capture is valuable in all four cases. Abandoned missions often teach the most.

## Trigger

- The user says: "wrap up the lesson", "end of session", "save the postmortem", "write the retro".
- A mission clearly ended (outcome known, conversation shifts topics). If no wrap-up has happened, offer one before moving on.
- The user is about to close the chat / switch contexts.

Don't wait to be asked every single time — offering a wrap-up at a natural end-point is part of the job.

## Steps

### 1. Fill every section the file has

Read the current session file (its path was returned by `start-session`). The file is mostly empty scaffolding + whatever bullets `capture-moment` added. Your job here is to fill every section that **exists in the file** — `mode` is a preset of which sections come pre-seeded, not a partition. A session can have any combination of sections, depending on:

- The original preset (`mode: session` vs `mode: spec`).
- Whether `--with-spec-axis` was passed at start.
- Whether `promote_to_session.sh` widened the file mid-mission.

Walk the file top-to-bottom. For each `## ` heading present, fill it using the full conversation as the source of truth.

Reference of what to put in each section (only fill the ones that exist):

- **Spec Reference** — pointer to the spec (URL / path / short title). If still empty, fill from the conversation now.
- **Mission** — one paragraph. What the user set out to do, in context.
- **Prompt Evolution** — numbered list. Each turn where the user changed direction gets a one-line summary + a one-line "why it shifted" note. Skip minor clarifications.
- **Steering & Course Corrections** — keep captured bullets; add any you missed. *User-driven* redirects only.
- **Decisions Made** — keep captured bullets; add any you missed. *Agent-side* choices where the user was hands-off. Mundane is fine — mundane decisions explain why the code looks the way it does.
- **Deviations** — keep captured bullets; add any you missed. Places the implementation intentionally departs from the spec, and *why*. Empty is a valid signal (followed the spec exactly).
- **Tradeoffs** — keep captured bullets; add any you missed. Alternatives considered and why the chosen one won. Include rejected paths.
- **What Worked** — concrete wins, with enough detail to reproduce.
- **What Failed / Frustrations** — failures and root cause if knowable. If still unclear, write "unclear — suspect X" rather than inventing one.
- **Skills & Tools Involved** — one row per skill/tool used. Columns: Name, Role, Quality (worked / mixed / misfired), Quirks. Be honest about misfires.
- **Takeaways** — concrete rules the next session should carry. Prefer testable ("if X, do Y because Z") over vibes ("be careful with auth").
- **Candidates for memory save** — see step 2 below; only fill in `mode: session`.
- **Open Questions** — leave these open; don't answer speculatively.
- **Links** — related sessions as `[[YYYY-MM-DD/session-HHMM-slug]]`.

### 2. Candidates for memory save (mode: session only)

This is the one mode-gated step. Read the current `mode` from frontmatter:

- **`mode: session`** — draft memory entries the user should consider promoting to `~/.claude/projects/.../memory/`. Format each one with full frontmatter so the user can copy-paste approve:
  ```
  - type: feedback
    name: integration_tests_real_db
    body: "Integration tests must hit a real database, not mocks.
           Why: ...
           How to apply: ..."
  ```
  Only propose candidates that are genuinely durable rules. If the session didn't surface one, say so — empty is better than noise. Skip the section header if it doesn't exist in the file.

- **`mode: spec`** — the Candidates section doesn't exist in the template; skip this step. Implementation notes are not durable cross-project rules. If a durable rule did emerge, either promote the session via `promote_to_session.sh` first (which adds the Candidates section), or capture it in a separate standard session later.

### 3. Update frontmatter

Edit the frontmatter in-place:

- `time_ended` — current `HH:MM`.
- `outcome` — `success` | `partial` | `failed` | `abandoned`. When unsure, pick `partial`; overclaiming `success` poisons the index.
- `model` — the model powering this session (e.g. `claude-opus-4-6`, `gpt-5.5`).
- `skills_used`, `tools_used`, `tags` — fill with the actual names.

### 4. Update the indexes

```bash
bash "$SKILL_DIR/scripts/update_index.sh" "<session-file-path>"
```

The script:
- Rewrites the row for this session in `_daily.md` (outcome column).
- Appends a row to `_INDEX.md`'s Session Log with the date, session, mission, outcome, and the first takeaway bullet.

### 5. Refresh the qmd index

```bash
bash "$SKILL_DIR/scripts/qmd_update.sh"
```

Fast no-op if nothing changed; safe no-op if qmd is not installed.

### 6. Report back to the user

Print, concisely:
- The session file path (so they can open it).
- The outcome.
- If the file has a `Candidates for memory save` section and you drafted any candidates, ask: "Want me to save any of these as memory?" (Don't auto-save.)
- If the file has a `Deviations` section, summarise it in one line on hand-off ("Implementation followed the spec with 2 intentional deviations; see Deviations.").
- A reminder to `git add project-memory/lesson-learned/<date>/ && git commit` when convenient.

## Curating Running Themes (optional)

If this session shares an obvious pattern with ≥1 prior session (same mistake recurring, same approach repeatedly working), manually update the `## Running Themes` section of `_INDEX.md` with a new entry or an updated one. This is hand-curation — don't automate it. Running Themes are the most useful part of the index for humans; keep them tight.

## What if the session was trivial?

If a mission was so small that wrap-up feels like ceremony, say so and ask the user if they'd rather skip the full template and just write a one-paragraph summary in the session file's Takeaways. Skipping is better than performative filler.
