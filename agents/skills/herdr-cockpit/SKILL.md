---
name: herdr-cockpit
description: "Guide the main agent in starting, assigning, observing, and integrating work across the user's six-pane Herdr coding cockpit."
license: MIT
---

# Herdr Cockpit

This skill defines the operating model for the user's six-pane Herdr coding
cockpit. It is guidance for the main agent after the human starts the layout;
it is not a second Herdr launcher and it must never start a nested Herdr
session.

The human startup flow is:

```text
outside Herdr:  herdr
inside Herdr:   choose a workspace and any tab, cd to the project, type hc
```

`hc` is the zsh entrypoint in `config/zsh/cockpit.zsh`. It uses the current
workspace, current tab, and current `$PWD` for the active project, then expands
a single-pane tab into this layout. The left column has two large controller
panes; the right column has four stacked worker/utility panes. Claude is always
launched from `~/Documents/github/idea` and is named `idea-center`:

```text
┌──────────────────────┬──────────────────────┐
│ main / Codex         │ lazygit / utility     │
│ orchestrator         │ lazygit               │
│                      ├──────────────────────┤
│                      │ worker-1 / Agy        │
│                      │ agy                   │
├──────────────────────┼──────────────────────┤
│ idea-center / Claude │ worker-2 / Pi         │
│ claude               │ pi                    │
│                      ├──────────────────────┤
│                      │ worker-3 / Pi         │
│                      │ pi                    │
└──────────────────────┴──────────────────────┘
```

It is idempotent for the expected six-pane layout and fails closed when the
current tab already contains an unrelated multi-pane layout. Existing four- and
five-pane layouts are not upgraded automatically because doing so would require
stopping or moving running agents. Open a new single-pane tab for the new
layout. Do not run bare
`herdr` from a managed pane: Herdr's nested-launch guard is intentional. For
control calls, require `HERDR_ENV=1` and use the existing Herdr CLI/socket API.

## Pane semantics

The top-left Codex pane is the orchestrator and owns the user-facing task,
decomposition, decisions, integration, and final report. The other panes are
workers or utilities, not independent owners of the overall task:

- `idea-center / Claude`: research the idea repo and discuss how its ideas can
  land in the current project. It is an advisor, not the owner of current-project
  implementation; Codex supplies the target repo context and makes the final
  implementation decision.
- `worker-1 / agy`: perform the bounded implementation or review assignment
  given by Codex and report its diff and tests. This cockpit intentionally
  starts workers in dangerous mode by default; that removes repetitive
  permission prompts but does not authorize the worker to broaden its task.
- `worker-2 / pi` and `worker-3 / pi`: perform separate reconnaissance,
  documentation, reproduction, or implementation assignments. Their distinct
  names let Codex query and steer them independently.
- `lazygit / utility`: provide a visual Git status and diff surface. It is not
  an agent and should not be used to stage, commit, reset, or publish changes
  without an explicit main-agent decision.

Codex, Agy, both Pi workers, and lazygit initially use the current project
checkout. The idea-center Claude pane uses `~/Documents/github/idea` instead.
Claude may inspect the target project read-only when Codex supplies its path,
but implementation and integration remain owned by Codex.

## Execution policy, worktrees, and task identity

The user's default execution policy is dangerous mode for Claude, Agy, and both
Pi workers. This is an intentional permission-prompt trade-off, not a transfer
of user authority. Every prompt must still state its scope, boundaries, and
evidence requirements; no worker may decide to push, merge, deploy, contact an
external service, or handle secrets unless Codex has explicit authorization.

The pane's live agent name is only a control handle. Codex must keep a durable
task record separate from Herdr names and pane IDs. At minimum, each task
record contains:

- `task_id` and exactly one `owner_agent`;
- target repository, branch or commit, and assigned worktree;
- objective, acceptance criteria, permissions, and budget;
- current pane/name plus a receipt containing status, files, checks, risks, and
  the next step.

Any task that can write files must receive an isolated Git worktree before
parallel execution. Never assign overlapping write tasks to the initial shared
checkout. Read-only reconnaissance may use the current checkout; implementation
work must use one worktree per task, and Codex owns integration back into the
main checkout. A successful prompt or green command is not a receipt, and a
receipt is not downstream acceptance until Codex verifies it.

## Main-agent control loop

At the beginning of a task, the main agent should:

1. Inspect the repository state and the current Herdr workspace, tab, and panes.
2. Resolve live pane IDs or live agent names from Herdr responses; never guess
   IDs from screen position or old output.
3. Decide whether the task needs building, review, scouting, or a sequential
   combination of those roles.
4. Allocate an isolated worktree for every task that may write, then record its
   `task_id`, owner, acceptance criteria, permissions, and budget.
5. Send each helper one narrow assignment with an explicit scope and evidence
   requirement.
6. Wait for the helper, read its output, inspect the resulting files and tests,
   and only then update the plan or assign the next step.
7. Integrate changes and perform the final verification from the main pane.

Use Herdr's agent control sequence for recognized agents. The stable live name
for each named worker is `idea-center`, `worker-1`, `worker-2`, or `worker-3`:

```bash
herdr agent list
herdr agent prompt idea-center "<question plus current-project context>" --wait --timeout 120000
herdr agent read idea-center --source recent-unwrapped --lines 120
herdr agent prompt worker-1 "<bounded Agy assignment>" --wait --timeout 120000
herdr agent prompt worker-2 "<bounded Pi assignment>" --wait --timeout 120000
herdr agent prompt worker-3 "<bounded Pi assignment>" --wait --timeout 120000
```

Use `pane run` for ordinary shell commands, tests, or starting a process in a
known shell pane. Use `agent get` and `agent read` before reacting to a
`blocked` state. Do not send blind keys to a pane that may contain unsent
input.

## Assignment contract

Every helper prompt should state:

```text
ROLE: idea-center | worker-1 | worker-2 | worker-3
TASK_ID: durable task identifier
OWNER_AGENT: exactly one named live owner
OBJECTIVE: one concrete outcome
WORKTREE: isolated checkout for any write task
SCOPE: files, commands, or question in scope
BOUNDARIES: what must not be changed or published
ACCEPTANCE: observable conditions for acceptance
EVIDENCE: tests, diff, citations, or reproduction required
RETURN: status, files, checks, risks, and blocker/next step
```

Every helper handoff must distinguish `done`, `blocked`, `unknown`, and
`in-progress`. A green command alone is not proof that the requested behavior
is complete. The main agent must preserve uncertainty and ask the user when a
decision, permission, worktree, secret, deployment, push, or merge is needed.

## Safety rules

- Before every Herdr CLI call, verify `test "${HERDR_ENV:-}" = 1`; stop if the
  call is not originating from a managed pane.
- Use the current workspace and tab as the default scope. Do not create,
  attach, focus, move, resize, close, or stop unrelated workspaces or panes.
- Use explicit pane IDs returned by Herdr and re-read state after layout or
  agent changes.
- Keep the `codexyolo` alias within the user's requested scope. Claude, Agy,
  and both Pi workers are started as named Herdr agents in dangerous mode by
  default. Dangerous mode does not authorize push, merge, deploy, external
  messages, paid actions, or secret handling.
- Never use dangerous mode as a reason to skip worktree isolation, task
  ownership, acceptance checks, or receipt verification.
- Keep final integration and external mutations in the main pane unless the
  user explicitly delegates them.
- If the Herdr client and server report a protocol mismatch, report it and
  stop; never stop the shared server to repair a client mismatch.

## Validation

From the dotfiles repository:

```bash
zsh -n config/zsh/.zshrc config/zsh/cockpit.zsh
python3 /Users/memorysaver/.codex/skills/.system/skill-creator/scripts/quick_validate.py agents/skills/herdr-cockpit
just validate-skills
```
