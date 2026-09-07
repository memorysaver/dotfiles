# Independent computer workspace

Every computer uses `~/Work` with the same directory meanings and workflow. Each owns its repositories,
Herdr sessions, agents, and runtime state. `herdr --remote` is a way to control the destination
computer; it does not turn these computers into a shared scheduler or synchronize their files.

## Directory and source map

```text
~/.dotfiles/                       Public workflow and installer source
~/idea/                            Private concepts, research and configuration
└── private-config/computers/<id>/orchestration-rules/
~/Work/
├── AGENTS.md       -> ~/.dotfiles/config/workspace/AGENTS.md
├── README.md       -> ~/.dotfiles/config/workspace/README.md
├── orchestration-rules/  -> selected private machine rules (public profiles when unbound)
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
over; a second pane is not a separate checkout. See [orchestration entrypoint](./orchestration-rules/README.md).

Remote control uses the destination host's paths, rules, permissions, and session. Identify that host
before issuing commands. Nothing in this layout authorizes dispatch to another computer.

## Public policy and private management

| Material | Owner |
| --- | --- |
| Portable layout, profiles, orchestration rules, installers, generic integrations | Public dotfiles |
| Computer roster, actual deployed agents, host roles and downstream management | Private idea repo: `private-config/computers/` |
| Product implementation, tests and product decisions | Receiving project repository |
| Live agent config, authentication, sessions and task runtime data | Destination computer |

The private management index is optional for a public installation. If a task needs private deployment
information and the index is unavailable, report that missing context rather than guessing or cloning
private repositories automatically. Generic public templates do not declare which agents are deployed.

## Read only when needed

- Local machine or agent management: [orchestration entrypoint](./orchestration-rules/README.md),
  then the selected computer's `agents.md`; the private fleet index is for fleet record maintenance.
- Concepts and research: `~/idea/AGENTS.md`. Product work follows the target repository's instructions.
- Setup, synchronization, link repair or migration: `~/.dotfiles/docs/workspace-setup.md`.

Already-bound computers receive rule-content updates by pulling both source repositories; existing
symlinks expose the updated files. Existing sessions must reread the entrypoints or start a new session.
