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
- Scheduling and delivery follow the selected host policy. For SIBYL Cloud hosts,
  Cloud → SIBYL daemon → project agent is the intended route. Check actual deployment readiness.
  Runtime tab/pane IDs are not durable project identity; legacy projects.yaml is not an active registry
  on retired dispatch hosts.
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

## Scheduling and agent lifecycle

There is no mandatory Computer Orchestrator role or Computer-to-Project forwarding hop.
For hosts adopting SIBYL Cloud, the intended route is Cloud scheduling/task intake → SIBYL daemon
→ `herdr agent` at the owning project checkout. Read the selected host's rules for deployment
status; an intended route is not evidence that the daemon or Cloud scheduling is available.
Project agents own implementation, workers, topic/release gates and artifact verification.
Preserve existing agents, panes, worktrees and uncertain execution state. Never infer task success
from idle/done or replay an uncertain task. Do not start services merely by reading instructions.
Use the installed Herdr skill and verified caller context for interactive agent control; do not
fabricate HERDR_ENV. No role name grants permission to publish, deploy or communicate externally.

Retired dispatch hosts do not automatically recover missing agents. Keep legacy registries and
receipts for rollback only; do not run broker startup, presence checks or callbacks on such hosts.
The selected private host rules define any explicitly authorized legacy exception on other hosts.

## Resolve this computer's paths

Read the local regular computer-id file and resolve the Work instructions/rules symlinks.
Read the resolved dotfiles identity guide, then selected private host rules and OS profile.
Use the existing workspace.toml and `lib/workspace-paths.py` for setup path discovery as needed.
Never move checkouts, overwrite identity or rebind a machine to make a check pass.
Credentials and runtime state remain local; private machine policy belongs in idea.
