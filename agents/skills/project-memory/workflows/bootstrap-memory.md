# Workflow: bootstrap-memory

Run this the **first time** a project needs a project-memory umbrella, and not again (it's idempotent, but there's nothing to gain from re-running it).

## Trigger

- `project-memory/_CONTEXT.md` does not exist in the current project, and
- The user wants to start capturing lessons (any of the other workflows would otherwise fail).

If `project-memory/_CONTEXT.md` already exists, skip this workflow and go straight to `start-session.md`.

## Steps

1. Confirm cwd is the project root (the place where you'd normally run tests or builds). If it looks wrong (e.g. a nested subdir), warn the user first.
2. Run the bootstrap script:
   ```bash
   bash "$SKILL_DIR/scripts/bootstrap_memory.sh"
   ```
   `$SKILL_DIR` is the folder this workflow lives in; if shell variables aren't handy, resolve the installed skill directory first and run the script from there.
3. The script creates:
   - `project-memory/.gitignore` — ignores qmd SQLite sidecars (the markdown stays in git). Umbrella scope.
   - `project-memory/_CONTEXT.md` — short description passed to qmd. Umbrella scope.
   - `project-memory/lesson-learned/_INDEX.md` — curated catalog seeded from the template. Subsystem scope.
   - A qmd collection named `<project>-memory` pointing at `project-memory/` (covers every subsystem).
4. Report the collection name to the user and suggest they commit the new folder: `git add project-memory && git commit -m "project-memory: bootstrap"`.

## Handling the qmd "not installed" case

The script prints a warning and exits 0. Everything still works via `rg` fallback; just tell the user that cross-session semantic search will be unavailable until they install qmd (`bun install -g @tobilu/qmd` or via their dotfiles `just tools`).

## Why this is a separate workflow

Keeping bootstrap out of `start-session` avoids the surprise of an unexpected qmd collection appearing in the index whenever someone runs a session from a new project — the user opts in explicitly.
