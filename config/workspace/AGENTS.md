# Work workspace

`~/Work` is a workspace, not a Git repository. Before working, locate the target repo, read its
nearest `AGENTS.md` and `README.md`, and check `git status --short --branch`. Preserve unrelated
repos and existing dirty worktrees.

## Directory map

- `github/`: regular or owner-led projects cloned from GitHub.
- `cowork/`: projects jointly developed with external collaborators. They may also be GitHub
  clones; the distinction is shared ownership, decision authority, and review workflow.
- `tries/`: Omarchy-managed workspace for projects created through the `try` CLI; do not treat it
  as an owner-led or cowork repository by default.

Treat every child as an independent repository. Do not mix their changes, commits, or releases.

## Legacy workspace migration

Some older machines may still keep GitHub projects under `~/Documents/github`. Treat that directory
as live user data until each project has been reconciled with `~/Work/github`.

- Do not bulk-move, copy, delete, or automatically rewrite projects from the legacy directory.
- Do not assume a project is missing just because it is absent from `~/Work`; check the legacy path.
- Before proposing a move, inventory the immediate children of both directories and identify name
  collisions, symlinks, linked worktrees, non-repository files, and nested repositories.
- For every repository in scope, read its nearest `AGENTS.md` and `README.md`, then record
  `git status --short --branch`, remotes, and `git worktree list` before changing its path.
- Propose a per-project migration plan and obtain explicit user confirmation before moving anything.
  Preserve the old path until the new location and dependent tooling have been validated.

## Idea hub

`github/idea/` is the default incubation and dispatch hub for new concepts, research, cross-project
reasoning, and reusable lessons. Read `github/idea/AGENTS.md` when entering it. Research remains in
`idea`; formal decisions, roadmaps, code, and tests belong to the receiving repo. A handoff is not
downstream acceptance or implementation.

## Machine configuration

`~/.dotfiles` stores reproducible computer configuration. For changes to shell, agent tooling,
Omarchy, terminals, or global development tools, check whether dotfiles manage the behavior. If so,
update and validate the dotfiles source, not only the deployed machine file. After exploratory live
changes, explicitly decide whether to persist them back. Read `~/.dotfiles/AGENTS.md` if present and
preserve its dirty worktree.
