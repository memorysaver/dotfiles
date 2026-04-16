# Workflow: query-memory

Pull relevant lessons from the project's memory when the user asks a question whose answer might live in past sessions.

## Trigger

- "Have we seen this before?"
- "What did we learn about X?"
- "Why did this fail last time?"
- "What approach did we settle on for Y?"
- A question where you suspect the answer is buried in prior sessions of the current project.

Run this *before* answering from general knowledge — project memory is cheaper and more specific than you reconstructing from scratch.

## Steps

### 1. Figure out the collection name

```bash
COLLECTION="$(basename "$PWD")-memory"
```

This matches what `bootstrap-memory` registered. The collection covers every subsystem under `project-memory/` (today: `lesson-learned/`; later: any sibling folders). If the current project hasn't been bootstrapped, qmd will say the collection doesn't exist; in that case, fall through to `rg` or suggest bootstrapping.

### 2. Quick-scan the curated index first

`project-memory/lesson-learned/_INDEX.md` has a hand-curated Running Themes section + a full Session Log. Grep it before firing up qmd — it's instant and often enough:

```bash
rg -i "<keywords>" project-memory/lesson-learned/_INDEX.md
```

If that surfaces the answer, cite the linked session file and stop.

### 3. Otherwise, query qmd

Prefer natural language with the hybrid `query`:

```bash
qmd query "<the user's actual question>" -c "$COLLECTION"
```

If the user wants a strict keyword match (e.g. for a specific error string), use `search`:

```bash
qmd search "<keywords>" -c "$COLLECTION"
```

Return the top 5 results. For each, show:
- The session file path (so the user can open it).
- The mission (from frontmatter).
- The one-line snippet qmd returned.

Then synthesise: in 2-3 sentences, what those prior lessons collectively say about the question. Don't just dump the results.

### 4. Fallback when qmd is missing or empty

If `command -v qmd` fails, or `qmd query` returns nothing useful:

```bash
rg -i -A 3 "<terms>" project-memory/
```

`-A 3` gives enough context to judge relevance. Strip false positives and present only the relevant hits. Scope to `project-memory/lesson-learned/` if you want to exclude future subsystems.

### 5. Cite, then answer

Always cite at least the session file path when drawing on memory. The user is expected to be able to trace any recalled claim back to the source. Prefer:

> We tried the JWT rotation approach in `project-memory/lesson-learned/2026-03-12/session-1015-auth-refactor.md` and it failed because the clock skew tolerance was 0 seconds.

over:

> We tried that before and it didn't work.

## What if there's no match?

Say so plainly: "Nothing in the project memory touches this." Then answer from general knowledge, and suggest capturing what you figure out so the next session has something to find.
