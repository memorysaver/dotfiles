# Work workspace

`~/Work` (or the configured workspace root) is this computer's workspace, not a Git repository. Each computer operates independently;
remote access controls the destination computer. Read [README.md](./README.md) for the directory
and ownership model. Before repository work, read the target's nearest `AGENTS.md` and `README.md`,
check `git status --short --branch`, and preserve unrelated repositories and dirty worktrees.

## Directory map

- `github/`: regular or owner-led repositories.
- `cowork/`: externally co-developed repositories; ownership and review workflow determine placement.
- `tries/`: experiments; preserve the `try` CLI's layout wherever it manages this directory.

Locate the actual Git root; category directories and supporting files are not repositories.
Keep changes, commits, and releases scoped to their owning repository.

## Task references

- Machine-specific work and Work-level coordination: enter
  [orchestration-rules/README.md](./orchestration-rules/README.md), then load the relevant machine,
  agent or dispatch reference. This is the only rules directory deployed under Work.
  Direct project development follows the project rules; it does not require creating a worker.
- Host agent inventory and downstream management: enter the selected
  `orchestration-rules/README.md`, verify local identity, then read its `agents.md`.
  Use `<resolved idea>/private-config/computers/README.md` only to maintain cross-computer records.
  Do not infer deployed agents from public templates or installable tools.
- New concepts, research, and reusable lessons: enter the resolved idea checkout and read its `AGENTS.md`.
  Research stays in idea; product decisions, code, and tests belong to the receiving repository.
  A handoff is not downstream acceptance or implementation.

## Configuration ownership

The resolved dotfiles checkout owns public, reproducible configuration and these linked workspace rules. For shell,
agent tooling, terminals, or global tool changes, check its nearest instructions and Git state and
update its managed source. After exploratory live changes, explicitly decide what to persist.
Machine-specific agent identities, deployment inventories, and management relationships belong in
the private idea repo. Credentials and runtime state stay local, outside both repositories.
Agent configuration templates are initial defaults; existing live configurations remain host-owned.
Never put credentials in prompts, pane labels, messages, or notes.

## Fixed local Herdr Orchestrator

Every managed computer must maintain one fixed agent named `orchestrator` with its cwd
at the configured Work root. Routing identity is the local server, agent name, configured kind
and canonical cwd; workspace labels, tab order and pane positions are runtime layout details. A local supervisor
maintains its presence while the computer and user service are available; Dagu also checks
presence. This agent coordinates that computer's authorized work and verifies results.
Project implementation belongs in each project's dedicated workspace. Direct human or agent
work inside a project does not require creating a second worker or routing through the Orchestrator.
Do not rename, close, repurpose, interrupt, or replace the fixed agent for an unrelated task.
A working, blocked, or unknown agent remains present; never restart it to clear an approval UI.
Only recover a confirmed missing agent. Never infer task success from Herdr idle/done alone.

## Resolve this computer's paths

Home paths in these documents are defaults, not proof of actual checkout locations. The local
regular file `~/.config/dotfiles/workspace.toml` may override dotfiles, idea, workspace, DAGs,
identity, private host records, and state directories; explicit `WORKSPACE_*`/`DOTFILES_DIR`
environment overrides take precedence. Use the selected checkout's `lib/workspace-paths.py`
or `workspace-orchestrator paths`, and verify existing Work symlink targets before host actions.
Do not move a checkout, create a second clone, or copy another computer's paths to match defaults.
Read the resolved dotfiles `config/workspace/orchestration-rules/identity.md`, then the selected
private rules. Private host manifests and workflow definitions belong in idea; common lifecycle
code and policy belong in dotfiles. DAG deployment links and runtime state remain local.
External Dagu/supervisor processes use the allowlisted broker and never fake `HERDR_ENV`.
Before business-event delivery, verify current instruction readiness. Presence or a submitted
bootstrap prompt alone does not prove rules were loaded or an event accepted. Dagu delivery
needs durable event identity, deduplication and an event-specific acknowledgment/result; never
infer these from idle/done. Service startup belongs to the host's service manager, not to reading
AGENTS.md. Presence maintains the role. Registered business events use the separate durable broker queue,
explicit instruction readiness and a real Herdr callback shell; see the resolved dotfiles
`docs/workspace-orchestrator.md`. Keep the model permission policy and project launchers unchanged.
