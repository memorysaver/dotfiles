# Local Computer → Project orchestration

The primary CLI is `herdr-dispatch`, a single Rust executable owned by dotfiles at
`tools/herdr-dispatch-rs`. `workspace-orchestrator` remains an alias for existing commands;
`herdr-dispatchd` remains the daemon alias. All point to the same immutable versioned release.

## Configuration and roles

`HERDR_COMPUTER_HOME` selects an existing absolute directory (unset: `~/Work`). Explicitly empty
or relative values fail. Default config is `<Computer home>/projects.yaml`; `--config` accepts
another YAML filename. Relative repo paths resolve from Computer home, including when YAML is
symlinked from private idea. Routing never falls back to workspace.toml or legacy WORKSPACE_ROOT.
The older TOML path resolver remains available for initial workspace provisioning only.

One YAML v1 manifest defines computer identity/mode/timezone, transport, runtime paths, optional
binding locations, project roles and registered tasks. See `config/workspace/projects.yaml.example`.
Bound hosts must match their regular local identity, selected private rules, managed Work
instructions and actual OS profile. Standalone mode must be explicitly selected. Duplicate/unknown
keys, aliases, merge keys, custom tags, multiple documents and invalid argv/types are rejected.

Computer uses `computer-orchestrator` at Computer home. Project uses `project-orchestrator-<key>`
at its exact Git root with readable AGENTS.md/README.md. The explicit short key is 1..11 characters;
no truncation or hashing. Project labels place a primary workspace; name/kind/cwd/native terminal
generation bind the route. Relative escapes, duplicate checkouts/keys and wrong occupants fail.
Each role's permission policy belongs to its registered launcher; role args configure
models/effort/service tier. Explicit launcher settings apply to newly started sessions.

## Delivery and acceptance

Dagu → durable broker queue → Computer acknowledgment → Project acknowledgment → registered
entrypoint → Project receipt → Computer result acceptance → Dagu registered verifier.
Every hop uses a distinct nonce and generation check. Frozen dates/slots/allowlisted env inputs
survive retries. New Dagu IDs contain computer/workflow/run/project/task. A completed historical
ID retains its original payload/name/receipts, with a migration name map used only for retry lookup.
There are no live legacy role aliases and no new execution claim for a completed retry.

Callback shell commands pin Computer home and an absolute YAML config. Bridge requires genuine
Herdr caller context, validates broker/native role agreement before splitting, and uses configured
broker_state_dir for narrowly validated stale Project context. It does not broaden model permissions.
Timeouts and uncertain effects retain claims/results for inspection; no automatic replay.

```sh
herdr-dispatch --skills
herdr-dispatch check
herdr-dispatch check --live
herdr-dispatch projects list
herdr-dispatch ensure
herdr-dispatch start --dry-run
herdr-dispatch start
herdr-dispatch projects ensure --project <project-id>
herdr-dispatch event submit --project <project-id> --task <task-id> --event-id <stable-id> --wait
herdr-dispatch event status --event-id <stable-id>
herdr-dispatch event verify --event-id <stable-id>
herdr-dispatch event submit --diagnostic read-only-probe --event-id <stable-id> --wait
herdr-dispatch broker tasks
```

`--skills`, help and version access no config/server. Config errors exit 2, operation failures 1;
status reads can succeed while pending.

`start` automatically validates and reloads the broker's pinned YAML in place, then starts/reuses
roles and arranges workspaces. `start --dry-run` does not apply settings or move/start agents.
Wait for unfinished events before changing YAML. Owner/root/socket/state changes require explicit
migration/deployment; existing sessions and runtime receipts survive ordinary configuration updates.
Default total wait is 21600 seconds, separate from each
registered task timeout. Optional env inputs may be absent; referenced placeholders require a
nonempty input. Values are data, never approval or credentials. Reconciliation requires existing
artifact/receipt inspection, explicit confirmation, decision and reason; never clear a claim.

## Installation and migration

Prepare private YAML and Work link before invoking the installer. Required Rust version is 1.89+.
The Linux installer copies the release artifact into a content-addressed libexec directory and
atomically switches aliases. `herdr-dispatch install` writes managed supervisor/server-monitor
units. Watch and broker units, host drop-ins and presence/business DAGs pin Computer home/config.
Keep broad legacy worker root policy separate from exact registered role roots. Raw role request-file
entrypoints are retired; broker v2 requires the validated manifest binding and registered task route.
Reserved current/retired role names cannot be used by ordinary workers.

For old deployments: drain full Dagu runs, stop scheduler/watch/broker writers, retain native
Herdr agents/server, save local release/config/state backups, rename only matching idle/done roles,
and atomically migrate event and worker stores to schema 2. Worker store envelope fences schema-1
binaries at startup. Preserve all historical events and execution-claim files, reset Computer
readiness, then start new broker/watch and run readonly two-hop acceptance before restoring schedules.
Schema-1 event stores are refused by the configured v2 broker; no implicit in-place upgrade.
Rollback must preserve all newer claims/results instead of copying old receipts back to replay work.

The healthy default Herdr server is adopted; server-monitor `KillMode=process` preserves panes.
Working/blocked/unknown occupants are preserved. This establishes Linux local acceptance only;
macOS service deployment and reboot/native restoration still require host-specific acceptance.
Detailed design and remaining cross-host acceptance requirements: `docs/herdr-dispatch-design.md`.
