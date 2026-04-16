# qmd integration

The project memory uses `qmd` (Quick Markdown Search) as its index backbone. One collection per project, scoped to the entire `project-memory/` umbrella, registered automatically during bootstrap.

## Collection naming

Name = `<basename(cwd)>-memory`. The `-memory` suffix avoids clashing with qmd's global collection registry, which is per-machine — every project's umbrella gets a uniquely-named collection.

## Umbrella scoping — why this matters

The collection's path is `<project-root>/project-memory/` with pattern `**/*.md`. Every subsystem folder under `project-memory/` is automatically indexed by the same collection. When a future subsystem (e.g. `project-memory/decisions/`) is added, no new qmd registration is needed — `qmd update` picks up the new files on next run.

## Adding a collection (what bootstrap does)

`qmd collection add` treats its positional argument as **a subfolder of the current directory** and refuses an arbitrary absolute path. The bootstrap script runs from the project root and passes `project-memory` directly:

```bash
qmd collection add project-memory --name "<project>-memory"
```

If the collection already exists, `qmd` rejects with `Collection '<name>' already exists`. The bootstrap script checks via `qmd collection show` first, so re-running is a safe no-op.

## Attaching human context

```bash
qmd context add "qmd://<project>-memory/" "$(cat project-memory/_CONTEXT.md)"
```

Text is a positional argument, **not** stdin. `qmd context list` shows what's attached.

## Query surfaces

```bash
# Natural language, with LLM query expansion + reranking (best):
qmd query "how did we handle auth token rotation?" -c <project>-memory

# Pure BM25 keyword (fastest, no LLM):
qmd search "auth token" -c <project>-memory

# Vector-only (requires `qmd embed` first):
qmd vsearch "token rotation" -c <project>-memory
```

Prefer `query`. Fall back to `search` when embeddings haven't been generated or the user wants an exact keyword match.

## Re-indexing after writes

`qmd update` re-indexes **all** collections; there's no per-collection flag on the `update` subcommand. Our wrapper calls it every time we write a new lesson. The operation is fast — indexed content is hashed and skipped if unchanged.

## Embeddings (optional)

`qmd embed` generates vector embeddings and enables `vsearch` + stronger `query` reranking. Skip in v1; BM25 + query expansion is usually enough. Run manually when the index matures:

```bash
qmd embed
```

## Fallback when qmd is missing

If `command -v qmd` fails, every read surface falls back to `rg`:

```bash
rg -i "<pattern>" project-memory/
# Or scope to one subsystem:
rg -i "<pattern>" project-memory/lesson-learned/
```

Writes never depend on qmd — the skill still captures lessons without it.

## Removing a collection

```bash
qmd collection remove <project>-memory
```

Useful when renaming a project or relocating the project-memory folder.
