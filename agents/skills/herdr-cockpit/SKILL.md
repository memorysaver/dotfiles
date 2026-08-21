---
name: herdr-cockpit
description: "Guide the main agent in starting, assigning, observing, and integrating work across the user's four-agent, five-pane Herdr coding cockpit."
license: MIT
---

# Herdr Cockpit

This skill defines the operating model for the user's four-agent, five-pane
Herdr coding cockpit. It is guidance for the main agent after the human starts
the layout;
it is not a second Herdr launcher and it must never start a nested Herdr
session.

The human startup flow is:

```text
outside Herdr:  herdr
inside Herdr:   choose a workspace and any tab, cd to the project, type hc
```

`hc` is the zsh entrypoint in `config/zsh/cockpit.zsh`. It uses the current
workspace, current tab, and current `$PWD`, then expands a single-pane tab into
this layout:

```text
┌──────────────────────┬──────────────────────┐
│ main / Codex         │ builder / Claude      │
│ codexyolo            │ ccyolo                │
│                      ├──────────────────────┤
│                      │ scout / Pi            │
│                      │ pi                    │
├──────────────────────┼──────────────────────┤
│ reviewer / agy       │ lazygit / utility     │
│ agyolo               │ lazygit               │
└──────────────────────┴──────────────────────┘
```

It is idempotent for the expected four-agent plus lazygit layout and fails
closed when the current tab already contains an unrelated multi-pane layout.
The previous four-agent layout is not upgraded automatically because doing so
would require stopping the existing Pi process. Open a new single-pane tab for
the new layout. Do not run bare
`herdr` from a managed pane: Herdr's nested-launch guard is intentional. For
control calls, require `HERDR_ENV=1` and use the existing Herdr CLI/socket API.

## Pane semantics

The top-left Codex pane is the main agent and owns the user-facing task,
decomposition, decisions, integration, and final report. The other panes are
roles, not independent owners of the overall task:

- `builder / ccyolo`: implement one bounded change. It may edit only the files
  explicitly assigned by the main agent and must report its diff and tests.
- `reviewer / agyolo`: challenge assumptions, inspect the implementation, run
  focused checks, and identify regressions or missing evidence. Treat its
  dangerous mode as execution capability, not as authorization to broaden the
  task.
- `scout / pi`: perform fast repository reconnaissance, documentation lookup,
  test reproduction, or small read-only experiments. It should not edit shared
  files unless the main agent explicitly reassigns it as an implementer.
- `lazygit / utility`: provide a visual Git status and diff surface. It is not
  an agent and should not be used to stage, commit, reset, or publish changes
  without an explicit main-agent decision.

All agent panes and the utility pane initially use the same checkout.
Therefore, never assign overlapping write tasks to multiple panes. If parallel
implementation is necessary, create separate worktrees first and keep
integration in the main pane.

## Main-agent control loop

At the beginning of a task, the main agent should:

1. Inspect the repository state and the current Herdr workspace, tab, and panes.
2. Resolve live pane IDs or live agent names from Herdr responses; never guess
   IDs from screen position or old output.
3. Decide whether the task needs building, review, scouting, or a sequential
   combination of those roles.
4. Send each helper one narrow assignment with an explicit scope and evidence
   requirement.
5. Wait for the helper, read its output, inspect the resulting files and tests,
   and only then update the plan or assign the next step.
6. Integrate changes and perform the final verification from the main pane.

Use Herdr's agent control sequence for recognized agents:

```bash
herdr agent list
herdr agent prompt agy "<one narrow, bounded assignment>" --wait --timeout 120000
herdr agent read agy --source recent-unwrapped --lines 120
```

Use `pane run` for ordinary shell commands, tests, or starting a process in a
known shell pane. Use `agent get` and `agent read` before reacting to a
`blocked` state. Do not send blind keys to a pane that may contain unsent
input.

## Assignment contract

Every helper prompt should state:

```text
ROLE: builder | reviewer | scout
OBJECTIVE: one concrete outcome
SCOPE: files, commands, or question in scope
BOUNDARIES: what must not be changed or published
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
- Keep high-trust aliases (`codexyolo`, `ccyolo`, and `agyolo`) within the
  user's requested scope. They do not authorize push, merge, deploy, external
  messages, paid actions, or secret handling.
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
