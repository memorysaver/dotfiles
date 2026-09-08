# OpenAB to Herdr dispatch

An optional Discord-facing orchestrator can use this integration. It does not directly call
Herdr's full socket API. Instead, it sends an approved high-level request to
the same-user Rust `herdr-dispatchd` broker:

```text
Discord → external orchestrator → herdr-dispatch → herdr-dispatchd → Herdr socket API
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
working directories below explicitly configured roots (default `~/Work`), recognized Herdr agent kinds, and these
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

`dispatch` requires `--confirmed`; pass it only within the user-authorized task and destination.
Users identify projects and outcomes; the orchestrator resolves canonical cwd, worker and fresh
layout IDs without asking for routine placement approval. Follow the
[autonomy and routing rules](../config/workspace/orchestration-rules/orchestrator.md) and
[external adapter](../config/workspace/orchestration-rules/external-dispatch.md).
The broker does not store prompts or agent output.
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
  --cwd ~/idea \
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
workspace. Use `--layout pane --target-pane-id <id>` for a non-disruptive split next to related
work within the authorized scope. Resolve and verify the ID from live state; users do not need
to specify it. Create a workspace only when no matching one exists or isolation was requested.
All created layout operations use
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
broker, not the Herdr workers. The shared adapter is in `~/.dotfiles/config/workspace/orchestration-rules/external-dispatch.md`;
existing orchestrator sessions must reread it to pick up the new follow-up workflow.

## Policy and deployment ownership

Read the [shared orchestration policy](../config/workspace/orchestration-rules/orchestrator.md) and
[external adapter](../config/workspace/orchestration-rules/external-dispatch.md). These describe the
reusable integration, not a particular host's installed agents. Host deployment records and local
E2E receipts are maintained in the private idea host-management collection. The public repository
owns broker source and generic tests; live authentication and broker state remain on the host.

## Repositories outside Work

`--allowed-root` may be repeated to allow separate canonical repository roots, such as `~/idea`
and `~/.dotfiles`, without permitting the entire home directory. Each configured root must exist;
symlink escapes and similarly prefixed sibling paths remain rejected. The default unit still allows
only Work. Actual host root lists belong in private configuration or a local systemd drop-in, not
in the public template. Existing `HERDR_DISPATCH_ALLOWED_ROOT` remains the single-root fallback when
no explicit flags are supplied. Restart the broker after changing its root list; workers are separate.
