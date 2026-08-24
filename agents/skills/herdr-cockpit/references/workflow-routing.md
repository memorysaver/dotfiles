# Cockpit Workflow Routing

Read this reference when the main agent must choose a workflow, prepare a
context packet, or assign a right-side worker. The main skill owns the safety
and Herdr-control rules; this file owns reusable task shapes and result formats.

## Operating model

The cockpit has one user-facing owner: the top-left Codex orchestrator. The
right three panes are a worker pool, not three permanent job descriptions. A
worker's live runtime (`agy` or `pi`) is a capability constraint, while the
workflow is the assignment. The orchestrator may reuse any idle worker for
scouting, status evidence, review, implementation, or documentation.

The bottom-left Claude pane is different: `idea-center` owns the idea repo as a
small upstream incubation space. It maintains ideas and helps reason about how
the current project could land them. It does not implement the current project.

There is exactly one owner per delegated task. The orchestrator remains the
source of truth for the overall task, even when a worker produces an artifact
or a useful recommendation.

## Workflow selection

| Workflow ID | Use when | Preferred route | Default side effects |
| --- | --- | --- | --- |
| `idea-maintenance` | An idea needs to be captured, reorganized, researched, or linked | `idea-center` | Write only the idea repo when explicitly requested |
| `idea-center-project-discovery` | The user wants related ideas/research and practical landing directions for a current project goal | `idea-center` + Codex | Read-only idea and target inspection; no downstream mutation |
| `brainstorm-to-land` | The user wants to explore how an idea could become a change in the current project | `idea-center` first, then Codex decides | Read-only target project; idea repo write only if requested |
| `status-explain` | The user asks what has happened, what remains, or where work is blocked | Codex plus the smallest useful set of read-only workers | No writes, commits, pushes, deploys, or paid actions |
| `context-audit` | The task is unclear or the current working context may be stale | Any idle right-side worker | Read-only inventory |
| `scout-research` | A bounded technical, product, repository, or source question needs investigation | Any capable right-side worker | Read-only unless the prompt explicitly grants a narrow artifact output |
| `eli5-project-state` | The user wants a deeper, simpler, visual explanation of current project state | Agy specifically when requested | Read-only source inspection plus an isolated HTML artifact that is opened for user review |
| `build` | A worker is asked to change code or configuration | Any right-side worker with an isolated worktree | Worktree-local writes only; Codex integrates |
| `review-verify` | A change, claim, or handoff needs independent checking | Any idle right-side worker | Read-only by default |

Do not fan out every request automatically. For a small status question, Codex
can inspect and answer alone. Fan out when another worker can gather a distinct
evidence slice, when the repository is large, or when the user asks for a
deeper explanation.

## Context packet

The orchestrator sends only the context needed for the assignment, not the
entire conversation. Refresh it when the branch, worktree, goal, or external
state may have changed.

```text
CONTEXT_SNAPSHOT_AT: timestamp
USER_GOAL: what the user is trying to understand or change
TARGET_REPO: absolute path or repository identity
TARGET_REF: branch and HEAD SHA, if known
WORKTREE: path and clean/dirty status
CURRENT_DELIVERY_STATE: PR/CI/staging/deploy facts, only if verified
VERIFIED_FACTS: observations with file/line, command, or source references
INFERENCES: useful interpretation, explicitly marked as inference
UNKNOWN_OR_STALE: missing evidence, conflicting state, or unverified claims
RELATED_TASKS: task IDs and their status
DECISION_NEEDED: the decision Codex will make after the receipt
TOPIC: the concrete project state or mechanism the artifact must explain
ARTIFACT_PATH: generated artifact path, if any
ARTIFACT_OWNER: the one live agent allowed to write or revise that artifact
ARTIFACT_MUTATION: owner-agent-only; Codex verifies and opens, never edits
REVIEW_STATUS: not-requested | pending | opened | accepted | changes-requested
```

For a write task, add the exact worktree and allowed paths. For a status or
ELI5 task, mark the packet `READ_ONLY: yes` and keep artifact output outside
the target checkout or in a disposable task worktree.

## Pre-dispatch context gate

Before sending the real task packet to any worker, send a cheap preflight to
the selected live agent. It must return exactly:

```text
CONTEXT_STATUS: clean | contaminated | unknown
CWD_STATUS: expected | unexpected
ACTIVE_TASK_STATUS: none | active | unknown
READY_FOR_NEW_TASK: yes | no
REASON: one sentence
```

Pass only when the result is `clean + expected + none + yes`. Treat every
`unknown` or `no` as a failed gate. On failure, send `/clear` to that pane
once, verify the live screen/status, and run the same preflight again. If it
still fails, route to another idle worker or report `blocked`; never compensate
for dirty context by sending a larger prompt or mixing in old task history.

The real task packet must be minimal: one `TOPIC`, current target snapshot,
scope, acceptance, and boundaries. Do not carry prior artifacts, rejected
proposals, or unrelated workflow design into the new task.

## Receipt contract

Every worker returns a receipt in this shape, even when it is blocked:

```text
STATUS: done | in-progress | blocked | unknown
TASK_ID: same durable ID as the prompt
OWNER_AGENT: live Herdr agent name
SUMMARY: one or two sentences
FACTS: verified observations with sources
FILES_OR_ARTIFACTS: paths, URLs, or none
CHECKS: commands, tests, or none
INFERENCES: interpretations, clearly marked
UNKNOWN_OR_RISKS: unresolved items
REVIEW_STATUS: not-requested | pending | opened | accepted | changes-requested
NEXT_STEP: what Codex should do next
```

### Artifact correction loop

The delegated worker owns the bytes of every generated artifact. This applies
to HTML, Markdown, screenshots, diagrams, and other disposable outputs as well
as files in an isolated worktree. Codex must not repair an artifact directly
after reading it, even when the repair is mechanically small.

When verification finds an acceptance gap:

1. Codex records the exact gap, evidence, and required acceptance condition in
   a correction prompt or receipt.
2. Codex sends that correction to the same live `ARTIFACT_OWNER` through
   Herdr, keeping the same `TASK_ID` unless the owner is genuinely blocked.
3. The owner revises or regenerates the artifact and returns a new receipt with
   `STATUS: done` or `blocked`; while waiting, use
   `REVIEW_STATUS: changes-requested`.
4. Codex re-reads the replacement artifact and source evidence. Only after the
   replacement passes may Codex run the platform opener and set
   `REVIEW_STATUS: opened`.

If the owner cannot complete the correction, preserve the blocker and report it
to the user. Do not silently transfer artifact ownership to the orchestrator.

`TOPIC` controls the artifact's content. Agy must explain that concrete topic,
not the workflow that dispatched it or a proposal about future experiments.

`done` means the acceptance conditions are met. A successful prompt, a green
command, or an artifact that looks plausible is not enough. Codex re-reads
source files, diffs, tests, and relevant live metadata before changing the
canonical ledger.

## Progress explanation workflow

When the user asks for current progress, Codex should produce a status report,
not a chronological dump of agent chatter.

1. Capture a fresh main-pane snapshot: current goal, branch/HEAD, diff, task
   plan, tests, PR/CI/deployment evidence, and known blockers.
2. Decide whether independent evidence is needed. If it is, assign only the
   missing slices, for example:
   - implementation slice: files, call paths, and current diff;
   - verification slice: tests, CI, runtime, or staging evidence;
   - product slice: acceptance criteria, decision history, or remaining scope.
3. Give each worker the same relevant snapshot but a different evidence
   objective. Do not ask three workers to repeat the same summary.
4. Reconcile receipts against the current checkout and mark every statement as
   `verified`, `first-party reported`, `inferred`, or `unconfirmed` as
   appropriate.
5. Answer in this order:

```text
CURRENT STATE: one-sentence conclusion
COMPLETED: accepted work with evidence
IN PROGRESS: active work and owner
BLOCKED: blocker, owner, and what would unblock it
UNKNOWN / NOT VERIFIED: claims that still lack proof
NEXT ACTION: the smallest useful next decision or task
```

Do not call a draft, prepared handoff, green local check, or partial gate
"complete". Do not claim production, real-user, CI, staging, or external
delivery status without current evidence.

## Idea-center workflows

For the full project/idea/research discovery procedure, read
[workflows/idea-center-project-discovery.md](../workflows/idea-center-project-discovery.md).

`idea-center-project-discovery` is the default when the user asks some version
of: "What in idea/research is relevant to what I am trying to do in this
project, and how could it land?" It is a read-only discovery and design brief,
not an implementation request. After Codex verifies the brief, a separate
`build`, `review-verify`, `idea-maintenance`, or `handoff` decision can follow.

### `idea-maintenance`

Use the Claude pane to maintain the idea repo's taxonomy, research notes,
cross-project links, and evidence labels. The prompt must state the exact idea
path or topic and whether writing is requested. It must not ask Claude to edit
the target project.

### `brainstorm-to-land`

Ask `idea-center` to connect an idea to the current project without turning the
conversation into an implementation commitment. The return should include:

- the idea and its current evidence status;
- two or three landing options in the target project;
- assumptions and open questions;
- the smallest experiment or decision that would discriminate between them;
- any idea-repo artifact changed, if writing was explicitly requested.

Codex then chooses whether to create a build, research, or review task. The
brainstorm is not itself approval to edit, deploy, or publish.

## Agy ELI5 project-state workflow

The upstream [Anthropic community `eli5` plugin](https://github.com/anthropics/claude-plugins-community/tree/main/eli5)
defines a `/eli5 <topic>` command that explains a topic as if to someone with
no prior knowledge and produces an HTML artifact with big visuals and few
words. The cockpit adopts that output contract for Agy; it does not assume the
Claude Code plugin or slash command is installed in the Agy runtime.

### Trigger

Use `eli5-project-state` when the user asks for a deeper understanding of the
project's current state, a simple visual explanation, or an ELI5-style answer.
The topic must be concrete, for example:

```text
Explain why this project is not ready to ship and what remains between the
current HEAD and the user's requested outcome.
```

### Assignment template

Send this to the live Agy agent, normally the available worker hosting Agy.
Resolve the name and current state from Herdr first; do not guess that
`worker-1` is still the Agy pane. If Agy is busy, queue the request or report
that it is waiting. Do not silently substitute Pi when the user explicitly
asked for Agy.

```text
ROLE: worker-N / agy
WORKFLOW: eli5-project-state
TASK_ID: <durable task id>
OWNER_AGENT: <live Agy agent name>
OBJECTIVE: Explain <concrete project-state topic> for a reader with no project context.
CONTEXT_SNAPSHOT: <fresh packet from the orchestrator>
TOPIC: <the concrete project state or mechanism to explain>
TARGET_REPO: <absolute path>
READ_ONLY: yes
ARTIFACT_DIR: <isolated disposable directory>
SCOPE: inspect the current goal, README/docs, branch/HEAD, working tree, relevant call paths, tests, and delivery evidence.
BOUNDARIES: do not edit source/config, commit, push, deploy, contact external services, or handle secrets.
ACCEPTANCE: produce a self-contained HTML explainer focused on TOPIC, with large simple visuals, very few words, a now-to-next map, and source references. Explain the topic itself, not a proposal about this workflow.
EVIDENCE: cite files/lines and commands for each material state claim; separate verified facts, inferences, and unknowns.
OUTPUT_FORMAT: HTML artifact plus the receipt contract below.
OPEN_FOR_REVIEW: yes
RETURN: STATUS, TASK_ID, SUMMARY, FACTS, FILES_OR_ARTIFACTS, CHECKS, INFERENCES, UNKNOWN_OR_RISKS, REVIEW_STATUS, NEXT_STEP.
```

### Agy's procedure and acceptance

1. Read the supplied context packet and verify the current repository state.
2. Trace the smallest set of files, tests, commits, and delivery records needed
   to explain the topic. Avoid a generic project tour.
3. Build a visual story: what the user wanted, what exists now, what is
   connected, what is missing, and what happens next. Use a simple flow,
   milestone map, or dependency diagram.
4. Write the HTML only into `ARTIFACT_DIR`; do not pollute the target checkout.
5. Return the artifact path and a short evidence-backed receipt. The worker's
   generation status can be `done` while the user review status is still
   `pending`. The worker remains the artifact owner for every correction.
6. If Codex finds an acceptance gap, it sends the gap back to Agy through
   Herdr. Agy revises the artifact and returns a replacement receipt; Codex
   does not edit the HTML itself.
7. After Codex confirms that the final artifact exists and passes the source
   checks, the main orchestrator opens
   it immediately for the user. Use the platform default opener from the main
   pane, for example:

   ```bash
   if command -v open >/dev/null 2>&1; then
     open "$artifact_path"
   elif command -v xdg-open >/dev/null 2>&1; then
     xdg-open "$artifact_path"
   else
     printf '%s\n' "Review artifact: $artifact_path"
   fi
   ```

   The open action belongs to Codex, not Agy: it makes the artifact visible to
   the user without asking a worker pane to steal focus or own the review.
8. Set `REVIEW_STATUS: opened` only after the opener command succeeds. Keep
   the task at review-pending until the user explicitly accepts it or requests
   changes. Opening a browser is not user acceptance.

The explainer is accepted only when it is specific to the current project,
readable without prior context, visually structured, and traceable to source
evidence. If Agy cannot produce HTML in its runtime, it must return
`STATUS: blocked` with a Markdown fallback attached, rather than claiming that
the ELI5 artifact is complete.

Codex opens the artifact immediately, checks its highest-impact claims against
the source, and then gives the user the concise explanation. The HTML artifact
is an aid to understanding, not a new source of truth and not a reason to
change code or advance delivery status. User review remains a separate
acceptance step.

## Dynamic dispatch rules

- Check live agent availability before assigning. Use stable live names, not
  pane positions or historical IDs.
- Give parallel workers non-overlapping evidence slices. Sequence tasks when
  the second task depends on files or decisions produced by the first.
- Any write-capable right-side task gets an isolated worktree. Read-only status,
  context, research, review, and ELI5 source inspection may use the current
  checkout, but artifact output stays isolated.
- Keep one durable task ID and one owner per assignment. If a worker becomes
  blocked, preserve that state and decide whether to retry, reassign with
  permission, or ask the user.
- A worker's result is a receipt for Codex to verify, not an automatic update to
  the user's project status.
