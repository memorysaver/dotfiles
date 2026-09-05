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
