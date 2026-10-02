# Fixed local Herdr Orchestrator

Every managed computer keeps one agent named `orchestrator` in its canonical Work management
workspace. A user supervisor calls the local allowlisted dispatch broker every 30 seconds;
the host Dagu presence workflow checks again every five minutes. Existing workers, active
prompts, blocked approval dialogs, and dirty repositories are preserved. These checks do not
execute business tasks or imply their success.

## Locations and ownership

Python 3.11+ resolves `~/.config/dotfiles/workspace.toml` without sourcing shell code. See
`config/workspace/workspace.toml.example`. Paths are absolute or begin with `~/`; spaces and
shell metacharacters are quoted as data. Environment overrides take precedence, then the
local path file, then home defaults. `WORKSPACE_HOSTS_DIR` defaults beneath resolved idea.
Use `workspace-orchestrator paths` to inspect effective paths. No clone or migration happens.

Private idea owns each host `orchestration-rules/orchestrator.toml` and `workflows/README.md`.
The manifest chooses computer ID, agent kind/args, interval and local broker socket. Credentials,
live pane IDs and execution receipts stay on the host. Public dotfiles owns shared mechanisms,
rules and examples; actual host inventories remain private. Existing broker allowed roots must
include the configured workspace and any separately authorized idea/dotfiles roots. For a custom
Herdr server, configure the broker's Herdr socket and the host manifest's broker socket together.

## Installation and availability

Read Work and selected private rules; verify local computer identity, Git state and actual OS.
Build/deploy the updated `herdr-dispatch` broker before enabling the supervisor. Broker deployment
must preserve all current Herdr workers. A matching Work workspace is reused. A known inventory without Work permits its creation;
ambiguous or unsupported snapshots fail closed rather than duplicating management workspaces.
From the chosen dotfiles checkout run `just workspace`, `just workspace-orchestrator`, then
`workspace-orchestrator ensure` and inspect the lifecycle receipt and actual agent.

Linux installs `workspace-orchestrator.service` in the user's systemd configuration; macOS installs
`dev.memorysaver.workspace-orchestrator.plist` as a user LaunchAgent. Generated service files use
resolved executable paths, so a checkout outside home is supported. Managed files are marked and
unmanaged conflicts stop installation. The Linux unit is restarted after updates; a changed macOS
LaunchAgent requires a deliberate bootout/bootstrap without touching Herdr panes. The server supervisor adopts the already healthy local server without stopping its panes.
It launches the native headless server only when the health socket is confirmed absent/refused.
Unexpected health responses and permission errors preserve the current server. The Linux unit
uses `KillMode=process` so refreshing the monitor does not terminate an adopted server or its
workers. User service enablement also registers startup at the next user-manager start/login;
reboot recovery still needs per-host acceptance. Dagu and the broker retain their own services
and must be verified on each host. Custom broker transports require an explicit matching
Herdr startup service; the default installer fails closed instead of launching the wrong server. Linux startup before login requires an existing user-manager
linger policy; macOS LaunchAgents start at login. A powered-off/sleeping host cannot run agents.
Authentication failures and agent startup approvals need a human; no approval bypass is allowed.

The configured DAGs directory is registered with a symlink to the selected host's workflow.
Preserve other project DAGs and merge any required queue changes into existing Dagu config.
Use the scheduler's actual binary to validate the YAML; CLI and service versions may differ.
Presence workflow concurrency is one run at a time; broker lifecycle mutations are serialized too.
A presence run verifies existence/location/kind, not task completion. Concrete recurring business
work needs a separate approved task workflow and durable result verification before deployment.

## Recovery and testing

The broker checks the live unique name and canonical cwd before discovering layout.
It resolves a management workspace only when the agent is confirmed missing. It never replaces a wrong-kind or
wrong-cwd occupant. Ambiguous workspace identity stops recovery. Herdr socket failures leave layout
untouched. A successful new agent receives the role bootstrap once. Presence does not prompt existing agents. The event consumer separately requests instruction
readiness when the native generation or rules version changes. Startup/prompt uncertainty is persisted as recovery-required; inspect the lifecycle
record before resolving it. Computer startup may retry at most three times only when the fixed name
is absent and fresh inventory proves its recorded pane closed; prior intents are archived privately.
A completed role restored as a shell is reused only after a 30-second native-restore grace period,
matching cwd, absent agent/session and process evidence that the shell alone is foreground.
Detected agents, pending restore, active commands, uncertain startup and transport errors are preserved.

Run `python3 tests/workspace-smoke.py`, `python3 tests/workspace-orchestrator-smoke.py`, and
`cargo test --locked` / `cargo clippy --all-targets --locked -- -D warnings` in the broker crate.
These isolated checks do not prove live agent startup, authentication or reboot recovery.

## Dagu event delivery

Routing identity is the local server, unique name `orchestrator`, configured kind and canonical
Work cwd (including foreground cwd when available). Layout is initial placement only.
The broker's allowlisted `orchestrator_event` operation owns durable delivery; ordinary
`dispatch` still creates project workers and does not target this fixed agent.

```text
Dagu → broker queue → Computer orchestrator (Work rules + ack)
 → fixed Project Orchestrator (repo rules + project ack)
 → execution claim → registered project handler → Project result
 → Computer result acceptance → Dagu completion → project artifact verifier
```

Private `projects.toml` enables each managed repo and fixes its `project-*` name, kind, canonical
repo-root cwd, optional launcher argv and registered tasks. `projects list` reports the actual enabled
count; internal Work probes are excluded. `projects ensure` maintains these roles, reusing their named
agents independent of layout. A missing role uses the matching primary project workspace, or creates
one when no match exists. Worktrees/episode tabs remain project-owned. Absolute/home paths as well
as paths relative to configured Work are supported. Initial labels never determine event routing.

For deliberate migration of an existing unnamed idle editor, use `projects ensure --project <id>
--adopt-pane <fresh-id>` after verifying cwd/kind and project ownership. Normal supervision never
adopts arbitrary panes. A recorded pane still present or uncertain startup requires inspection;
project errors are reported individually while other project events continue. The configured project
launcher is preserved. Enabling a project authorizes supervision of its fixed role, not business work.

Models retain their existing permission policy. `event bridge --callback ready|consume|
project-consume|computer-complete --nonce <stage-nonce>` checks the genuine fixed-agent caller and
creates its own callback shell without focus. Only the Project callback runs business entrypoints;
Computer consume acknowledges and forwards. Each hop uses a distinct nonce and pins the native
terminal generation through acknowledgment and execution claim. Once claimed, its callback owns
completion: the claim capability can report its durable result even if the Project TUI exits.
An unclaimed replaced Project is marked uncertain and never automatically replayed. Project results leave the top-level event accepted until Computer acknowledges
its result. This is cooperative role separation within the same local user, not isolation from a
malicious same-user process. Existing Codex tool daemons can retain a closed caller ID. For Project callbacks only, a stale
caller fallback requires the private second-hop capability, frozen role route and current terminal
generation. Other callers fail closed. This fallback reads the default local broker store; custom
state placements must supply a working native caller context. No fabricated HERDR_ENV or permission overrides are used.

Callback panes are runtime implementation details; successful callbacks close only their own shell
after durable receipt. Failures preserve the shell/log. A model can use Herdr pane reads for retained
output; broker requests require host-owned temporary writes and cannot run in the read-only sandbox.

Use a stable idempotency key combining computer, workflow, run/event and logical step identity.
Retries of the same event reuse that key; a different payload for the same key is a conflict.
Queue events while the agent is working. Blocked, unknown, wrong-kind or wrong-cwd agents
receive no input. Keep one consumer per named Orchestrator and persist delivery intent before
sending. Timeout, disconnect or prompt uncertainty requires reconciliation, not blind retry.
Business handlers still need idempotency or effect reconciliation; this is not exactly-once execution.

Separate `queued`, `sending`, `submitted`, `accepted` and `completed`/`failed` receipts, with
`delivery_unknown` for uncertainty. Herdr `agent.prompt` success proves terminal submission;
`agent.wait` follows lifecycle state rather than an individual event. Require an acknowledgment
and result tied to the event ID. A Dagu enqueue step may report successful durable enqueue;
a workflow requiring task completion must wait for the correlated result and verify artifacts.

Before launch, validate the resolved Work AGENTS.md/README source links and the agent's instruction
loader. Before accepting events, require readiness for the current computer, canonical cwd,
native conversation generation and instruction/config revisions. The existing `bootstrapped`
phase records prompt submission, not this semantic acknowledgment. Rules loaded once in an old
conversation do not establish readiness after a configuration change.

User services own deterministic server/broker/monitor/scheduler startup. AGENTS.md defines agent
behavior; merely reading it does not start services. Native Herdr conversation restore requires
compatible agent integrations and client attachment context; preserve pending restore instead of
starting a competing agent. Detached headless restart and reboot must be tested per host before
claiming conversation recovery. See the official [agent automation](https://herdr.dev/docs/agent-automation/)
and [session restore](https://herdr.dev/docs/session-state/) contracts.

Acceptance must cover concurrent events, repeated Dagu retries, wrong cwd/instruction sources,
changed rules, busy/blocked agents, uncertain submission, native restore races, and a read-only
Dagu event with durable acknowledgment/result. Existing presence tests do not cover this contract.

## Operations

Submit from Dagu with `workspace-orchestrator event submit --project <id> --task <task>
--dagu --wait --timeout 21600`; then use `event verify` with the same project/task/--dagu identity.
Manual submissions require a stable `--event-id`. Submission freezes trigger date/slot and
registered argv; changed registration requires reconciliation. Same-day tasks expire without
execution after their trigger day. Computer deliveries and each project delivery are serialized separately; delegated work releases
the Computer input slot. Busy/blocked/unknown projects retain their queues. Size Dagu waits for
queue time plus handler timeout. A wait timeout leaves the durable event pending: inspect/reuse
that event ID; a new run ID creates another event and is not a safe retry.

Inspect `event list` or `event status --event-id <id>`. `reconcile --confirmed --event-id <id>
--decision drop --reason <reason>` can cancel queued work. Inspected uncertain work can be
reconciled as completed using a verified `--result-file`; claimed executions cannot be resent.
Uncertain readiness can use `reconcile-readiness --confirmed --decision resend --reason <reason>`
only after inspecting the agent/composer. It invalidates the previous nonce. Never blindly replay.

The broker stores metadata in its private state directory; execution claims/results/logs live in
resolved workspace state. Claims are persisted both locally and in the broker before side effects.
Timeout kills the subprocess group and records effects as unknown; the event stays accepted for
artifact reconciliation. Entrypoint completion may mean dispatch only; project verification and
producer topic/release approval remain separate. State/receipts/nonces/pane IDs do not enter Git.

Deploy in this order: commit reviewed sources; build/test; restart only the broker; restart the
orchestrator supervisor (adopt verified editors first); run a read-only end-to-end probe; then trigger business work. Preserve the
Herdr server and existing workers throughout. Unit tests do not replace live acceptance.
