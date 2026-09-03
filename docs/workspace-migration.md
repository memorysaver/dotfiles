# Workspace migration

Use this guide only when explicitly asked to migrate an older machine from
`~/Documents/github` to `~/Work/github`.

## Safety rules

- Inspect first; never bulk-move, clone, copy, or delete repositories.
- Treat both locations as live user data.
- Handle one repository at a time and require explicit user confirmation before moving it.
- Keep the old path until the new location and dependent tooling are verified.
- Do not record private repository names or machine inventory in this public dotfiles repository.

## Read-only audit

For the repository in scope:

1. Read its nearest `AGENTS.md` and `README.md`.
2. Check `git status --short --branch`, `git remote -v`, and `git worktree list`.
3. Check the destination for name collisions, symlinks, nested repositories, and non-repository files.
4. Identify tooling that stores the old absolute path.
5. Present a per-repository migration and rollback plan without executing it.

## Migration gate

Move only after explicit approval. Then validate the new path, Git status, remotes, worktrees, and
dependent tooling before considering removal of the old path. Never automate the migration across
multiple repositories.
