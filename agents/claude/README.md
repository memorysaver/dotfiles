# Claude Code Agent Notes

## Codex Plugin & jj (Jujutsu) Compatibility

### How the Codex plugin uses version control

The `codex-companion` plugin (`scripts/lib/git.mjs`) shells out directly to `git` for all review context: diffs, commit log, branch detection, and working tree state. It calls `ensureGitRepository()` which requires a `.git` directory to be present.

### Colocated jj (single workspace)

When using `jj git init --colocate`, a `.git` directory exists alongside `.jj/`. This means:

- `ensureGitRepository()` passes — the plugin loads normally
- `git diff`, `git log`, `git merge-base` all work
- **Caveat:** jj does not use git's staging area, so `git diff --cached` always returns empty. Only the unstaged diff (`git diff`) reflects working copy changes — which is sufficient for review purposes.

### jj workspaces (colocated, multiple workspaces)

jj workspaces map to git worktrees. Limitations:

- `git branch --show-current` returns empty (detached HEAD), falling back to `"HEAD"`
- `detectDefaultBranch` may fail or give wrong results if jj hasn't synced git refs
- Branch-mode review (`collectBranchContext`) is unreliable

### Git worktrees (native git)

Fully supported. The plugin uses `cwd`-relative git calls throughout, so each worktree is treated independently.

### Compatibility matrix

| Scenario | Works? | Notes |
|---|---|---|
| Plain git | Yes | Full support |
| Git worktrees | Yes | Full support |
| jj colocated, single workspace | Mostly | Staging always empty; unstaged diff is accurate |
| jj colocated, multiple workspaces | Partial | Branch detection unreliable; `HEAD` may be detached |

### Workaround: use `codex:rescue` instead of `/codex:review`

`codex:rescue` dispatches the Codex CLI agent directly into your working directory via Bash, bypassing `lib/git.mjs` entirely. The agent has full shell access and can use `jj` commands natively.

When in a jj workspace, skip `/codex:review` and use `/codex:rescue` with an explicit prompt:

```
Review my current changes. Use `jj diff` for the diff and `jj log -r @` for context.
```

Specify the base change explicitly if needed:

```
Review changes since @- using `jj diff -r @` and `jj log -r '..@'`.
```

This gives equivalent review quality without hitting the `git.mjs` limitations.
