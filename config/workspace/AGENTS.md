# Work workspace

`~/Work` is this computer's workspace, not a Git repository. Each computer operates independently;
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
- Host agent inventory and downstream management: use the private
  `~/idea/private-config/computers/README.md` when available.
  Do not infer deployed agents from public templates or installable tools.
- New concepts, research, and reusable lessons: enter `~/idea/` and read its `AGENTS.md`.
  Research stays in idea; product decisions, code, and tests belong to the receiving repository.
  A handoff is not downstream acceptance or implementation.

## Configuration ownership

`~/.dotfiles` owns public, reproducible configuration and these linked workspace rules. For shell,
agent tooling, terminals, or global tool changes, check its nearest instructions and Git state and
update its managed source. After exploratory live changes, explicitly decide what to persist.
Machine-specific agent identities, deployment inventories, and management relationships belong in
the private idea repo. Credentials and runtime state stay local, outside both repositories.
Agent configuration templates are initial defaults; existing live configurations remain host-owned.
Never put credentials in prompts, pane labels, messages, or notes.
