# project-memory — at a glance

A git-committed memory system for a project. Lives at `project-memory/` at the
project root. Per-session retrospectives go under `lesson-learned/<date>/`,
indexed for cross-session retrieval via qmd.

For workflow details see [SKILL.md](SKILL.md). This README is the routing map:
**how the skill picks a mode at start, and how it decides when to capture
mid-mission.**

> **Mode is a capture-shape preset, not a partition.** Sections are additive:
> a session can gain spec-axis sections at start (`--with-spec-axis`) or be
> widened mid-mission with `promote_to_session.sh`. The frontmatter `mode`
> field records the *current* preset, not a one-shot choice.

---

## 1. Routing: which mode does a new mission get?

The agent picks `--mode=session` or `--mode=spec` *before* invoking
`start_session.sh`. The script refuses to run without `--mode`, so this
decision is forced.

```
                  ┌──────────────────────────────────┐
                  │   New mission starting           │
                  │   (user described what they want)│
                  └────────────────┬─────────────────┘
                                   │
                                   ▼
              ┌──────────────────────────────────────────┐
              │ Did the user provide a written spec?     │
              │ (PRD / RFC / ADR / design doc / formal   │
              │  prescriptive requirements)              │
              └──────┬───────────────────────┬───────────┘
                     │ yes                   │ no
                     ▼                       │
       ┌──────────────────────────────┐      │
       │ Is the mission to IMPLEMENT  │      │
       │ that spec?                   │      │
       │ (not debug / refactor /      │      │
       │  extend an existing impl)    │      │
       └──────┬─────────────────┬─────┘      │
              │ yes             │ no         │
              ▼                 │            │
   ┌───────────────────────┐    │            │
   │ Is the deviation /    │    │            │
   │ decision axis the     │    │            │
   │ most valuable record? │    │            │
   │ (not conversation     │    │            │
   │  evolution)           │    │            │
   └───┬───────────────┬───┘    │            │
       │ yes           │ no     │            │
       ▼               ▼        ▼            ▼
 ┌──────────────┐   ┌──────────────────────────────┐
 │ mode = spec  │   │           mode = session     │
 │              │   │   (default; superset of      │
 │ template =   │   │    capture surfaces)         │
 │  spec        │   │                              │
 │ capture =    │   │ template = standard          │
 │  continuous  │   │ capture  = notable           │
 │  (forced)    │   │           (or --continuous   │
 │              │   │            for long missions)│
 └──────────────┘   └──────────────────────────────┘
```

**Signals that strongly suggest `spec`:**
- User pasted or linked a spec and said "implement this" / "build this" /
  "follow this design".
- Structured, prescriptive language ("must support X", "shall return Y").
- Reference to an RFC, ADR, PRD, or "the spec".

**Signals against `spec` (even if a spec is mentioned):**
- Mission is to *debug* or *refactor* an existing implementation.
- The "spec" is vague brainstorming, not prescriptive.
- Mission is exploratory ("let's see what we can do with…").

**When unsure → pick `session`.** It captures a superset of surfaces;
nothing is lost. Full rule lives in
[workflows/start-session.md](workflows/start-session.md).

---

## 2. Capture moments: do I record this turn?

After every turn, the agent decides whether to append a bullet via
`append_capture.sh`. The decision depends on the session's `capture_mode`
(set at start, recorded in frontmatter).

```
                  ┌────────────────────────────┐
                  │   A turn just happened     │
                  └──────────────┬─────────────┘
                                 │
                                 ▼
                  ┌──────────────────────────┐
                  │  Read capture_mode from  │
                  │  session frontmatter     │
                  └────┬──────────────────┬──┘
                       │ notable          │ continuous
                       ▼                  ▼
        ┌─────────────────────┐   ┌──────────────────────────┐
        │ Was the turn        │   │ Did the turn do          │
        │ NOTABLE?            │   │ SUBSTANTIVE work?        │
        │                     │   │                          │
        │ • user steered      │   │ • wrote code             │
        │ • frustration       │   │ • ran a tool             │
        │ • surprising win    │   │ • made a decision        │
        │ • skill misfired    │   │ • surfaced a deviation   │
        │ • durable takeaway  │   │ • picked a tradeoff      │
        │ • user said         │   │                          │
        │   "capture this"    │   │ (pure clarifying Qs and  │
        │                     │   │  acknowledgements skip)  │
        └───┬──────────────┬──┘   └───┬──────────────────┬──┘
            │ yes          │ no       │ yes              │ no
            ▼              ▼          ▼                  ▼
       ┌─────────┐    ┌───────┐  ┌─────────┐         ┌───────┐
       │ capture │    │ skip  │  │ capture │         │ skip  │
       └────┬────┘    └───────┘  └────┬────┘         └───────┘
            │                         │
            └───────────┬─────────────┘
                        ▼
            ┌──────────────────────────┐
            │   Pick the section       │
            │   (see table below)      │
            └──────────────┬───────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │ bash append_capture.sh <key> "<msg>" │
        └──────────────────────────────────────┘
```

### Section keys by mode

```
 mode: session                    mode: spec
 ─────────────                    ─────────────
   steering    (user redirected)    decision   (agent picked path)
   decision    (agent picked)       deviation  (impl ≠ spec)
   failed      (didn't work)        tradeoff   (alternative rejected)
   worked      (worth reproducing)  open       (for user to confirm)
   takeaway    (durable rule)
   open        (unresolved Q)
```

**Tiebreaker:** user-driven → `steering`. Agent-driven → `decision`. If
plausibly two sections, pick the one closer to `takeaway` (session) or
`decision` (spec).

Full rule, including continuous-mode guidance and quality bar, lives in
[workflows/capture-moment.md](workflows/capture-moment.md).

---

## 3. Lifecycle, end to end

```
   user starts                  mission running                       mission ending
        │                              │                                    │
        ▼                              ▼                                    ▼
 ┌─────────────┐    pick mode    ┌─────────────────────────┐    fill sections + index
 │ bootstrap-  │ ──────────────▶ │ start-session.sh        │ ──────────────────────▶ wrap-up
 │ memory.sh   │                 │  --mode=<session|spec>  │      ▲
 │ (one-time)  │                 │  [--continuous]         │      │
 └─────────────┘                 │  [--with-spec-axis]     │      │
                                 │  [--spec-ref=…]         │      │ append-only,
                                 └───────────┬─────────────┘      │ many times
                                             │                    │
                                             ▼                    │
                                  ┌─────────────────────┐         │
                                  │ session file        │         │
                                  │   mode + capture_   │─────────┤
                                  │   mode + spec_ref   │         │
                                  │   in frontmatter    │         │
                                  └──────────┬──────────┘         │
                                             │                    │
                              ┌──────────────┴───────────┐        │
                              │                          │        │
                              │  if drift past spec:     │        │
                              │  promote_to_session.sh   │        │
                              │  (additive widen,        │        │
                              │   mode: spec → session)  │        │
                              │                          │        │
                              └──────────────────────────┘        │
                                                                  │
                                  ┌───────────────────────────────┴───┐
                                  │ capture-moment via append_capture │
                                  │  decision / steering /            │
                                  │  deviation / tradeoff / ...       │
                                  │  (keys driven by sections present)│
                                  └───────────────────────────────────┘
                                                                       ┌──────────────┐
                                                                       │ qmd index    │
                                                                       │ refreshed,   │
                                                                       │ daily +      │
                                                                       │ umbrella     │
                                                                       │ updated      │
                                                                       └──────────────┘
```

---

## Where things live in this folder

```
SKILL.md                    canonical entry point — read this first
README.md                   this file — routing map at a glance
workflows/
  bootstrap-memory.md         first time in a project
  start-session.md            mode selection rule + script invocation
  capture-moment.md           when + which section + how to append
  wrap-up-session.md          fill remaining sections, update indexes
  query-memory.md             retrieve from prior sessions
references/
  template-session.md         mode: session template (10 sections)
  template-spec-session.md    mode: spec template (lighter, spec-axis)
  template-daily.md           per-day overview seed
  template-index.md           subsystem catalog seed
  template-context.md         umbrella qmd-collection description
  frontmatter-schema.md       field definitions, mode + capture_mode rules
  qmd-integration.md          query commands, fallback to rg
scripts/
  bootstrap_memory.sh         create umbrella + register qmd collection
  start_session.sh            new session (refuses without --mode);
                              supports --with-spec-axis and --spec-ref
  append_capture.sh           append a timestamped bullet
  promote_to_session.sh       widen a spec session into the standard shape
                              (additive only, preserves all content)
  update_index.sh             update _daily.md + _INDEX.md on wrap-up
  qmd_update.sh               re-index the qmd collection
```
