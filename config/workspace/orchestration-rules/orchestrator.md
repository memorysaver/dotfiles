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
4. Reuse a matching workspace and suitable existing worker. If none exists and the task authorizes
   dispatch there, create a dedicated project workspace. Resolve ambiguous destinations first.
   Use a task tab for independent work or a specific relevant pane split for closely related work.
   A pane visiting a repo does not make its enclosing general workspace the project's home.
5. Pass the objective, destination cwd, constraints, expected deliverable, and verification criteria.
   Honor the user's existing authorization; ask only for missing scope or authority. Creating a pane
   does not authorize a repository, worktree, destructive action, or unrelated task.

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
