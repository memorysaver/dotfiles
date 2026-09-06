# Independent computer workspace

Every computer uses `~/Work` with the same directory meanings and workflow. Each owns its repositories,
Herdr sessions, agents, and runtime state. `herdr --remote` is a way to control the destination
computer; it does not turn these computers into a shared scheduler or synchronize their files.

## Directory and source map

```text
~/.dotfiles/config/workspace/       Public policy source, versioned per computer
~/Work/
├── AGENTS.md       -> ~/.dotfiles/config/workspace/AGENTS.md
├── README.md       -> ~/.dotfiles/config/workspace/README.md
├── computer-rule/  -> ~/.dotfiles/config/workspace/computer-rule/
├── workspace-rules/ -> ~/.dotfiles/config/workspace/workspace-rules/
├── github/                       Regular or owner-led repositories
├── cowork/                       Externally co-developed repositories
└── tries/                        Experiments; respect existing try-managed layouts
```

The same structure does not require the same clone list. Each repository and worktree has its own
Git state. Shared ownership and review authority distinguish `cowork` from `github`, regardless of
where the repository is hosted. Keep existing experiments in place; do not rename try-generated
folders. Create a repository or worktree only when the task calls for it.

## Two ways to work

Start a management agent in a Herdr workspace rooted at `~/Work` to locate projects, dispatch tasks,
and follow results. Use a project's dedicated workspace to implement work or join an existing worker.
The orchestrator and the person use the same project workspaces. Check ongoing work before taking
over; a second pane is not a separate checkout. See [orchestrator rules](./workspace-rules/orchestrator.md).

Remote control uses the destination host's paths, rules, permissions, and session. Identify that host
before issuing commands. Nothing in this layout authorizes dispatch to another computer.

## Public policy and private management

| Material | Owner |
| --- | --- |
| Portable layout, profiles, orchestration rules, installers, generic integrations | Public dotfiles |
| Computer roster, actual deployed agents, host roles and downstream management | Private idea repo: `deep-research/personal-productivity/host-management/` |
| Product implementation, tests and product decisions | Receiving project repository |
| Live agent config, authentication, sessions and task runtime data | Destination computer |

The private management index is optional for a public installation. If a task needs private deployment
information and the index is unavailable, report that missing context rather than guessing or cloning
private repositories automatically. Generic public templates do not declare which agents are deployed.

## Setup and updates

From the dotfiles checkout, run `just workspace` to create the directories and all four links.
Existing conflicting paths are preserved and cause setup to stop. Inspect them before explicitly
choosing the existing `DOTFILES_LINK_MODE=backup` migration option.

Update each computer's dotfiles checkout separately, preserving dirty changes, then rerun
`just workspace`. A symlink follows that computer's checkout; it does not pull updates from Git.
Use `just link-dry-run` to inspect managed links and `just doctor` for the broader read-only health
check. `just unlink` removes managed workspace links but leaves repositories and real files intact.
Agent templates are seeded once; these operations do not synchronize live agent configuration.

Existing project migrations are deliberate per-repository work, governed by the dotfiles
`docs/workspace-migration.md` guide. Setup does not clone, move, or bulk-sync repositories.

Workspace link lifecycle regression check: `python tests/workspace-smoke.py` from dotfiles.
