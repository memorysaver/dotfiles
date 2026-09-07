# Local workstation orchestrator

Read this when managing or dispatching work from `~/Work`. The role is local to the destination
computer and independent of the agent product or access channel. Direct development inside a
project follows that repository's instructions without requiring another worker.

## Establish context and route work

1. Identify the destination host, current Herdr session, requested goal, and target repository.
   A remote client controls that host; do not schedule work on another computer implicitly.
2. Read the target's nearest instructions and README, check Git status and ongoing workers, and
   identify overlapping file ownership before dispatch. Preserve existing work.
3. General work and cross-project coordination belong in the topmost workspace rooted at `~/Work`.
   Project work belongs in the project's dedicated workspace, including `~/idea` and `~/.dotfiles`
   outside Work. Match canonical cwd, Git root, and
   worktree identity; labels, sidebar position alone, and UI focus are not ownership evidence.
4. Reuse a matching project workspace and a suitable existing worker after checking ongoing work.
   If the workspace exists but lacks a suitable worker, create a task tab or relevant pane split
   inside that workspace. Create a project workspace only when no matching workspace exists;
   an explicitly requested isolated workspace is an exception. A pane visiting a repo does not
   make its enclosing general workspace the project's home.
5. Pass the objective, destination cwd, constraints, expected deliverable, and verification criteria.
   Honor the user's existing authorization; ask only for missing scope or authority. Creating a pane
   does not authorize a repository, worktree, destructive action, or unrelated task.

## Autonomy and human intent

Users identify projects and desired outcomes, not workspace, tab or pane IDs. Resolve the project
from conversation context and repository evidence, then discover fresh IDs from live state yourself.
Do not ask users to supply IDs or approve routine placement. When a task and destination are already
authorized for dispatch, selecting a suitable worker and creating the necessary workspace, tab or
pane within that scope are execution details. Honor any explicit worker or placement preference.

Default to a new task tab for independent work; a new pane split next to related work is also allowed
when it preserves the existing worker and focus. Reuse suitable workers without interrupting or
redirecting unrelated work. If several workspaces match the same checkout, choose a suitable one
from live context; different plausible repositories or worktrees require resolving the ambiguity.
Ask in project terms, not internal IDs, only when missing scope or destination prevents a safe choice,
or when an action would interrupt existing work, close/move/repurpose user panes, or exceed existing
authorization. Prefer a non-disruptive new tab when it resolves a placement issue within scope.
Report the chosen project and route without treating the update as a new approval gate.

## Control and follow-up

Inside a Herdr-managed pane, verify `HERDR_ENV=1`, read the Herdr skill, and use installed CLI help
for current syntax. Use explicit fresh IDs or a unique live agent name; preserve focus for background
work. External services use the [external dispatch adapter](./external-dispatch.md), not a fabricated
Herdr caller context. If the appropriate control surface is unavailable, report the limitation.

After dispatch, report host/session, repository/cwd, workspace/tab/pane, worker, and task. Monitor
actual output and verify deliverables and relevant checks; idle/done state alone is not success.
If output or a worker disappears, inspect recorded artifacts before deciding whether a new task is
needed. Do not replay mutations or assume the old pane still hosts the same worker.

The person may enter any project workspace to develop directly. Check whether a worker is still
writing before handing over the same files. Separate concurrent edits by agreed ownership or an
explicit worktree when needed. Leave layouts open; do not close, move, relabel, or repurpose existing
user panes without authorization. The top-level Work workspace remains the management entrypoint.

## Private deployment context

For local agent management, enter `~/Work/orchestration-rules/README.md`, verify the destination
identity, then read `agents.md` in that selected directory. Read
`~/idea/private-config/computers/README.md` only when maintaining cross-computer records.
If private rules or inventory are unavailable, report the missing context instead of inferring
deployed agents from public templates. Actual agent rosters, deployment choices, and downstream
relationships stay in private idea. Public dotfiles contains only this common mechanism; active
tasks and session IDs remain machine-local runtime data.
