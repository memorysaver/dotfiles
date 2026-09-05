# OpenAB to Herdr dispatch

`openab-omarchy` is a Discord-facing orchestrator. It does not directly call
Herdr's full socket API. Instead, it sends an approved high-level request to
the same-user Rust `herdr-dispatchd` broker:

```text
Discord → openab-omarchy → herdr-dispatch → herdr-dispatchd → Herdr socket API
```

The Rust broker source and the two compatible binaries live in
`tools/herdr-dispatch-rs/`. Build and deploy them with:

```bash
just herdr-dispatch
```

The broker listens on:

```text
~/.config/herdr-dispatchd/dispatch.sock
```

The socket and state directory use mode `0700`/`0600`. The broker only permits
working directories below `~/Work`, recognized Herdr agent kinds, and these
operations:

```text
health       verify the Herdr socket
snapshot     inspect the current Herdr session
tasks        list routing metadata (never prompts or output)
history      query recent durable metadata events, optionally by task or Discord thread
result       combine stored evidence and live output; preserve evidence when the pane is gone
dispatch     create workspace/tab/pane, start an agent, submit a prompt
status       read one dispatched agent's current state
read         read recent output for one dispatched agent
wait         wait for idle/done/blocked/unknown
```

`dispatch` requires `--confirmed`; the OpenAB orchestrator must only pass that
flag after the user confirms the proposed repository, cwd, worker, layout, and
permissions in Discord. The broker does not store prompts or agent output.
After `agent.start`, it waits for Herdr to report the named agent as
`interactive_ready` before sending `agent.prompt`, so the startup transition
cannot race the prompt submission.

## CLI examples

Health and inventory:

```bash
herdr-dispatch health
herdr-dispatch snapshot
herdr-dispatch tasks
```

Create an isolated Herdr workspace and send a task to Codex:

```bash
herdr-dispatch dispatch \
  --confirmed \
  --task-id idea-20260905-001 \
  --kind codex \
  --cwd ~/Work/github/idea \
  --layout workspace \
  --label idea-dispatch \
  --prompt 'Inspect the approved idea task and return a receipt. Do not broaden scope.'
```

The response contains the authoritative workspace, tab, pane, and live agent
name returned by Herdr. Use those values through the task id:

```bash
herdr-dispatch status --task-id idea-20260905-001
herdr-dispatch read --task-id idea-20260905-001 --lines 120
herdr-dispatch wait --task-id idea-20260905-001 --timeout-ms 3600000
```

Use `--layout tab --workspace-id <id>` for an independent tab in an existing
workspace. Use `--layout pane --target-pane-id <id>` only when the user has
approved splitting that exact pane. All created layout operations use
`focus=false` so the user's current view is preserved.

The broker is deliberately not a general remote shell. It does not accept raw
Herdr methods, arbitrary commands, guessed IDs, or credentials in prompts.
The daemon uses Tokio for concurrent local socket clients and keeps the same
allowlist, readiness ordering, task-state format, and systemd hardening as the
previous implementation.

## Durable history and result recovery

```bash
herdr-dispatch history --limit 20
herdr-dispatch history --discord-thread-id <discord-thread-id>
herdr-dispatch history --task-id <task-id> --limit 200
herdr-dispatch result --task-id <task-id> --lines 120
```

History is newest-first. Pass the returned RFC3339 `next_before` value as `--before` to
page backwards (an empty page ends the query). Dispatch accepts optional
`--discord-thread-id`, `--discord-message-id`, and `--parent-task-id` metadata. The parent
must exist in the retained task registry. A linked task is a new dispatch subject to the same
confirmation and routing rules; it never silently retries the parent's prompt.

The private state directory is `~/.config/herdr-dispatchd/`, **not** `~/Work`:

- `tasks.json`: atomic latest routing/state registry, compatible with legacy records.
- `history/YYYY-MM-DD.jsonl`: append-only UTC daily metadata journal, directory 0700/files 0600.
  It records layout creation, agent readiness (`agent_started`), successful prompt submission
  (`working`), dispatch failures (`blocked`), and state changes observed through status/wait/result.
  It starts after layout creation; validation/snapshot/layout failures before receipt persistence
  are not journaled. It is not an autonomous completion monitor or a transactional Herdr audit.
- Journald remains daemon diagnostics, not a task transcript.

No prompts, raw errors, or pane output enter the event journal. Unchanged status polls do not append
events or refresh retention. Queries default to 20 events, cap at 200, and scan newest daily files
first with bounded result memory. A corrupt/partial line is skipped and counted in `malformed_lines`.

Retention: keep the entire current UTC day plus the previous **62 days**, ensuring at least two
months. On startup, requests, and an hourly timer (once per UTC date), remove only strictly older
owned daily files; never delete within the retention floor to meet a byte cap. Idle/done registry
entries older than that cutoff are pruned too; unresolved/unknown/blocked summaries remain so work
is not silently forgotten. Thus storage scales with transitions in the retention window, plus
unresolved summaries, rather than prompt sizes or poll frequency. This is not a fixed-byte quota;
very high task volume or never-resolved tasks can still require operator review. Pruned history is
not recoverable without backups. Pruning never closes Herdr panes or touches repository files.

`result` preserves the stored receipt if Herdr is offline, the pane was closed, or its occupant
was replaced. It only reads by the original unique agent name, never falls back to reading the
old pane's replacement. It distinguishes `agent_present`, `original_agent_missing`, `pane_missing`,
`unavailable`, and `output_unavailable`. A moved named agent can still be read by name. The original
receipt remains historical; live status is separate. Neither idle/done nor pane loss verifies a
deliverable (`success_verified` is always false). Inspect artifacts or propose a new read-only
parent-linked verification task; do not rerun mutations. Legacy records have no fabricated history.

Run regression checks with `cargo test --locked` and `cargo clippy --all-targets --locked -- -D warnings`
in `tools/herdr-dispatch-rs`, then deploy with `just herdr-dispatch`. Deployment restarts only the
broker, not the Herdr workers. The computer-rule source is symlinked into `~/Work/computer-rule`;
existing orchestrator sessions must reread it to pick up the new follow-up workflow.

### Installed E2E verification (2026-09-06 Asia/Taipei)

Ten Rust tests cover persistence, duplicate polling, 62-day retention boundary, unresolved summary
retention, pagination, damaged-tail recovery, live output, missing/replaced occupants, and offline
Herdr. Clippy, formatting, installer shell syntax and diff checks passed.

The installed CLI/broker dispatched Grok task `dispatch-history-e2e-20260906-001` into a fresh tab
in the topmost Work workspace. Its live receipt contained the independently verified SHA-256 of
the symlinked orchestrator rule and the correct 62-day/result instructions. After closing only
that test tab, result reported `pane_missing`; all four lifecycle events survived broker restart.
Task `dispatch-history-e2e-20260906-002`, linked to the first through `parent_task_id`, independently
queried the missing parent's history and verified the same artifact without replaying work.
Both test tabs were closed after completion; task records remain. User focus stayed at w2/t3/p3.
Existing replaced-agent lookup also correctly returned `original_agent_missing`.

This exercises CLI → installed broker → real Herdr → real Grok → result/history, including closure
and restart, not a newly sent Discord message. Discord ingress itself still needs a user-side smoke
message; no Discord IDs were invented for these terminal-initiated tests.
