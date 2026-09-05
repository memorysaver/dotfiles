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

## Idea hub

`github/idea/` is the default incubation and dispatch hub for new concepts, research, cross-project
reasoning, and reusable lessons. Read `github/idea/AGENTS.md` when entering it. Research remains in
`idea`; formal decisions, roadmaps, code, and tests belong to the receiving repo. A handoff is not
downstream acceptance or implementation.

## Computer-specific rules

Before machine-specific or host-agent work, identify the current computer profile and read only the
matching file under `~/Work/computer-rule/`: `mac.md`, `omarchy-server.md`, or
`omarchy-desktop.md`. If the profile is ambiguous, ask before making machine-specific changes.

When acting as the host-native `openab-omarchy` orchestrator, also read
`~/Work/computer-rule/openab-orchestrator.md`. These files supplement this common workspace policy;
nearest repository instructions still take precedence. Never put credentials in prompts, messages,
pane labels, or research notes.

## Machine configuration

`~/.dotfiles` stores reproducible computer configuration. For changes to shell, agent tooling,
Omarchy, terminals, or global development tools, check whether dotfiles manage the behavior. If so,
update the source in dotfiles, not only the deployed machine file. After exploratory live changes,
explicitly decide whether to persist them back. Read `~/.dotfiles/AGENTS.md` if present and
preserve its dirty worktree.
