# Idea-center Project Discovery

This workflow lets the main Codex orchestrator use the bottom-left
`idea-center` Claude pane to connect a user's current project goal with the
upstream `idea` repository. It produces an evidence-labeled design brief:
related ideas, relevant research, downstream relationships, landing options,
and the smallest useful next decision.

It is discovery and design support. It is not downstream implementation,
formal product approval, a roadmap commitment, or a handoff receipt.

## Ownership and boundaries

`idea-center` is an upstream concept-incubation advisor. It may inspect:

- `/Users/memorysaver/Documents/github/idea` for ideas, research, handoffs, and
  lessons;
- the target project path supplied by Codex, read-only, to understand the
  current implementation and constraints.

The target project remains the source of truth for formal decisions, roadmap,
code, tests, and delivery. Do not edit it from this workflow. Do not claim an
idea is adopted, a handoff is received, or a feature is landed without
target-owned evidence. Do not create or modify an idea/research/handoff record
unless the user explicitly asks for that follow-up; if writing is requested,
route it to a separate `idea-maintenance` or handoff task with an isolated
idea-repo worktree.

Preserve the idea repo's evidence labels:

- `verified`: supported by a first-party source, current source tree, or a
  check that was actually run;
- `first-party reported`: claimed by the project or source but not independently
  reproduced;
- `observed`: directly seen in a dated target snapshot or worktree;
- `inferred`: a reasoned connection, explicitly marked as inference;
- `unconfirmed`: still missing source, experiment, or target-owned evidence.

## Inputs from the orchestrator

Before prompting `idea-center`, Codex supplies a compact context packet:

```text
USER_INTENT: what the user wants to achieve or understand
DECISION_QUESTION: the design or research decision this workflow should clarify
TARGET_REPO: absolute path or repository identity
TARGET_REF: branch and HEAD SHA, if known
TARGET_WORKTREE: clean/dirty state and relevant changed paths
TARGET_SNAPSHOT: relevant README, architecture, call paths, tests, and known gaps
CONSTRAINTS: time, compatibility, safety, budget, or authority boundaries
EXISTING_TASKS: related task IDs and their statuses
READ_ONLY: yes
```

If the user intent or target is ambiguous, preserve that as `unknown` and ask
one focused question or produce bounded alternatives. Do not fill the gap with
a remembered project story.

## Progressive discovery path

`idea-center` follows the idea repo's own progressive disclosure path. It uses
indexes and keywords to narrow the read set; it does not load the entire repo.

1. Read the idea repo root `AGENTS.md` and `README.md` to establish its role and
   the current upstream/downstream boundary.
2. Read `rules/README.md` and select only the rule for the requested artifact:
   - `rules/repository-structure.md` → new idea or collection ownership;
   - `rules/research.md` → evidence, research maturity, or project-specific
     research;
   - `rules/handoffs.md` → an existing relationship, delivery, or receipt;
   - `rules/repository-structure.md` → a lesson learned or lifecycle question.
3. Read the relevant collection index:
   - `ideas/README.md` for unverified seeds and short observations;
   - `deep-research/README.md` for source-backed topics and topic indexes;
   - `handoffs/README.md` for target relationships and latest delivery pointers;
   - `lesson-learned/README.md` for experiences that were actually executed.
4. Open only the candidate topic, handoff relationship, or lesson records whose
   titles and links match the user's intent or the target project's vocabulary.
5. Read the target project's supplied snapshot and compare the candidate's
   assumptions with current target evidence. If the target is dirty, keep the
   dirty-state boundary in the result.

The direction of truth is:

```text
ideas → deep-research → handoff relationship → downstream project
  ↑                                             │
  └──────────── new observation / lesson ──────┘
```

Research may influence multiple projects. A handoff records one research-to-
target relationship and its deliveries; it is not a copy of the research or a
permission slip to implement.

## Analysis steps

### 1. Frame the user's desired outcome

Rewrite the request as a concrete outcome and decision question. Include what
would make the answer useful now. Separate:

- the user's desired capability or understanding;
- the current project's observed state;
- the research or idea connection being investigated;
- the decision Codex will make after the brief.

### 2. Build a relevance map

For every candidate artifact, record:

| Field | Meaning |
| --- | --- |
| `artifact` | Exact idea, research, handoff, or lesson path |
| `relation` | Direct, adjacent, historical, or no meaningful relation |
| `why_relevant` | Specific connection to the user goal or target constraint |
| `evidence_status` | `verified`, `first-party reported`, `observed`, `inferred`, or `unconfirmed` |
| `target_impact` | Which target concern it might inform |
| `gap` | What is still missing before the connection is useful |

Do not promote a keyword match into a design recommendation. A candidate is
useful only when its problem, mechanism, constraint, or evidence connects to
the target question.

### 3. Produce landing options

Give two or three options at the right level of commitment:

1. **Small experiment** — the cheapest target-owned check that could confirm or
   reject the connection.
2. **Bounded integration direction** — where the idea could fit in the current
   architecture, what it would replace or complement, and the acceptance
   evidence needed.
3. **Separate spinout or defer** — when the idea is too broad, the target is not
   the right owner, or evidence is too weak to integrate now.

For each option, state benefits, constraints, assumptions, risks, owner,
required evidence, and what it does not decide. Recommend the smallest next
decision, but label it as `inferred` or `proposed` unless the user has already
accepted it.

### 4. Define the handoff boundary

If the research could affect a project, explain whether this is:

- only a discovery note;
- a future research topic;
- an existing handoff relationship needing another delivery; or
- a downstream-owned implementation decision.

Do not create a handoff record during discovery. A later handoff task must
commit the research source revision first, preserve delivery history, and wait
for downstream receipt evidence according to `rules/handoffs.md`.

## Output contract

Return a concise Traditional Chinese brief when the user is speaking Chinese;
otherwise match the user's language:

```text
STATUS: done | in-progress | blocked | unknown
WORKFLOW: idea-center-project-discovery
TASK_ID: durable task identifier
OWNER_AGENT: idea-center
USER_INTENT: normalized desired outcome
DECISION_QUESTION: the question this brief helps Codex decide
TARGET_SNAPSHOT: observed target state and SHA/dirty boundary
RELATED_IDEAS: paths plus relevance and evidence status
RESEARCH_EVIDENCE: paths, source claims, experiments, counterexamples, and gaps
HANDOFF_RELATIONSHIPS: relevant target relationships and delivery/receipt status
LANDING_OPTIONS: two or three bounded paths with owners and acceptance evidence
RECOMMENDATION: smallest next decision or experiment, clearly marked proposed/inferred
DECISION_BOUNDARY: what remains target-owned or requires user authorization
UNKNOWN_OR_RISKS: unresolved facts, stale state, or invalidating conditions
FILES_OR_ARTIFACTS: read paths or explicitly requested upstream changes
CHECKS: commands or source validations actually performed
NEXT_STEP: what Codex should verify, ask, or dispatch next
```

Every material claim must have a source path, topic link, target file/line,
command, or explicit status label. If no relevant idea or research is found,
return that negative result with the search scope; do not invent a connection.

## Prompt template

```text
ROLE: idea-center
WORKFLOW: idea-center-project-discovery
TASK_ID: <durable task id>
OWNER_AGENT: idea-center
OBJECTIVE: Find idea/research relevant to the user's current project goal and propose bounded landing directions.
USER_INTENT: <user's desired outcome>
DECISION_QUESTION: <what Codex needs to decide>
TARGET_REPO: <absolute path>
TARGET_REF: <branch and HEAD SHA>
TARGET_WORKTREE: <clean/dirty state and relevant paths>
TARGET_SNAPSHOT: <current implementation, docs, tests, and known gaps>
CONSTRAINTS: <scope, safety, authority, time, or compatibility constraints>
READ_ONLY: yes
SCOPE: follow the idea repo's AGENTS.md progressive path; inspect only relevant indexes, topics, handoffs, lessons, and supplied target files.
BOUNDARIES: do not edit the target repo, commit, push, deploy, create a handoff, or turn a proposal into an implementation commitment.
ACCEPTANCE: return the output contract with evidence labels, related artifacts, two or three landing options, a smallest next decision, and explicit unknowns.
OUTPUT_FORMAT: Traditional Chinese design brief plus receipt fields.
```

## Orchestrator follow-up

After `idea-center` returns:

1. Codex verifies the highest-impact connections against the referenced idea
   paths and current target snapshot.
2. Codex presents the brief as `evidence → interpretation → landing options →
   decision boundary`, preserving uncertainty.
3. Only after a user decision does Codex dispatch a separate `build`,
   `review-verify`, `idea-maintenance`, research, or formal handoff workflow.
4. If implementation starts, the target repo owns the resulting design and
   tests. If research matures, the idea repo owns the research source revision;
   do not copy target-owned truth back upstream.

The success condition is not "an interesting idea was found". It is that the
user can see why the connection matters now, what evidence supports it, what
could be built or tested, who owns the next decision, and what remains unknown.
