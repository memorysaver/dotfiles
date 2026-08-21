---
name: herdr-quad-orchestrator
description: "Explicitly set up and coordinate a four-pane Herdr workspace for a project: Codex --yolo controller at top-left, ccyolo/Claude at top-right, agy at bottom-left, and Pi at bottom-right. Use only when the user asks for this quad layout or asks the controller to start or inspect these four agents."
license: MIT
---

# Herdr Quad Orchestrator

Use this skill for the user's explicit four-agent Herdr layout:

```text
┌──────────────────────┬──────────────────────┐
│ Codex --yolo         │ ccyolo (Claude)       │
│ controller           │ claude-yolo           │
├──────────────────────┼──────────────────────┤
│ agy                  │ pi                   │
└──────────────────────┴──────────────────────┘
```

The skill provides a deterministic launcher at
`scripts/launch-quad.sh`. Run it from the project directory inside a
Herdr-managed pane:

```bash
bash /path/to/herdr-quad-orchestrator/scripts/launch-quad.sh \
  --cwd "$PWD" \
  --label "herdr-quad:$(basename "$PWD")" \
  --session herdr-quad
```

The launcher creates a new workspace, keeps the current working directory in
all four panes, uses `--no-focus`, and starts these exact agent commands:

- top-left: `codex --yolo`
- top-right: `claude --dangerously-skip-permissions --rc` (the current `ccyolo` alias)
- bottom-left: `agy`
- bottom-right: `pi`

It does not send an initial task prompt. Leave the agents idle until the user
assigns work or the controller has a concrete coordination task.

## Safety and topology

- Before every Herdr CLI call, verify `test "${HERDR_ENV:-}" = 1`. If it fails,
  stop and explain that this agent is not in a Herdr-managed pane.
- Create a new workspace by default. Do not reuse, resize, focus, close, or
  move panes that this run did not create.
- Parse pane IDs from each JSON response. Never derive them from sidebar order
  or from example IDs.
- The four panes initially share one checkout. Do not assign simultaneous write
  tasks to multiple agents. If parallel edits become necessary, use one
  worktree per editing agent and integrate through the controller.
- `--yolo` and `--dangerously-skip-permissions` are user-selected high-trust
  modes. Do not add further permissions, push, merge, deploy, or external
  writes unless the user separately authorizes them.
- If the Herdr client and server report a protocol mismatch, do not stop the
  default server: stopping it exits existing pane processes. Report the
  mismatch and use an explicitly isolated named session only when authorized.

## Controller workflow

After startup, the top-left `controller` owns task decomposition and final
integration. It should:

1. Inspect the current task, repository state, and all four agent states.
2. Keep each helper assignment narrow and independently verifiable.
3. Use the Herdr sequence `agent prompt` -> `agent wait` -> `agent read`.
4. Treat `blocked` as a human decision point and `unknown` as non-completion.
5. Require each helper to report its files, branch/worktree, tests, and blockers.
6. Keep merge, push, deployment, and other external mutations with the user or
   an explicitly authorized controller step.

Use stable live agent names rather than guessed pane IDs:

```bash
herdr agent list
herdr agent prompt agy "<one narrow task>" --wait --timeout 120000
herdr agent read agy --source recent-unwrapped --lines 120
```

Inspect `agent get` and `agent read` before responding to a blocked state. Do
not send blind keys to a pane containing unsent input.

## Validation

From this skill directory, validate the launcher and the shared skill:

```bash
bash -n scripts/launch-quad.sh
bash /Users/memorysaver/.codex/skills/.system/skill-creator/scripts/quick_validate.py .
```

The project-level validator is also useful:

```bash
just validate-skills
```
