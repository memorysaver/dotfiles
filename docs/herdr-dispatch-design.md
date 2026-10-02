# herdr-dispatch: computer and project routing

Status: Linux local YAML routing implementation is deployed for the first bound host. The requirements
below also define cross-host acceptance; macOS and reboot/native restoration remain unverified.

## Interface and locations

The primary executable is `herdr-dispatch`. `HERDR_COMPUTER_HOME` selects the management root;
when unset, the default is `~/Work`. An explicitly empty, relative or invalid value is an error.
Expand only `~`/`~/`, then canonicalize the existing directory. This root is the Computer role's
cwd, the base for relative project paths, and the default location of `projects.yaml`.
Do not infer this root from the current working directory, hostname, a project, or legacy
`WORKSPACE_ROOT`/workspace.toml. Installation must check for inconsistent old root settings rather
than silently rebind a machine. The installer persists the chosen root explicitly in service env.

`--config <path>` selects a YAML file; default: `${HERDR_COMPUTER_HOME}/projects.yaml`.
An explicit relative config filename resolves from the caller's cwd; paths *inside* the YAML
always resolve according to the rules below, regardless of config/symlink location. A missing
config is an error for config-dependent commands; there is no implicit TOML fallback or merge.
`--help`, `--version`, and `--skills` work without config, Git repositories, or a running server.

```sh
herdr-dispatch --skills
herdr-dispatch check                  # validate config and repository locations, no mutation
herdr-dispatch check --live           # also inspect configured local server/roles, no startup
herdr-dispatch projects list
herdr-dispatch ensure                 # Computer presence, operator/supervisor use
herdr-dispatch start --dry-run        # inspect managed roles/order without mutation
herdr-dispatch start                  # start/reuse roles and arrange managed workspaces
herdr-dispatch pump                   # advance authorized queued events
herdr-dispatch paths                  # resolved routing paths, no mutation
herdr-dispatch install                # operator deployment
herdr-dispatch projects ensure --project indiehackin-media
herdr-dispatch event submit --project indiehackin-media --task transport-probe --dagu --wait
herdr-dispatch event status --event-id <id>
herdr-dispatch event verify --event-id <id>
herdr-dispatch --config /path/projects.yaml event submit --project <id> --task <task> --event-id <id>
herdr-dispatch daemon
herdr-dispatch watch
herdr-dispatch server-watch
```

Keep the familiar event/project subcommands. A free-form prompt or CLI-supplied entrypoint cannot
replace a registered task. The legacy worker-dispatch client remains a separate compatibility
surface (`broker` namespace), not the event route used by Dagu. Existing legacy command spellings
need explicit parsing adapters; argv[0] must no longer route all `herdr-dispatch` calls to the old
broker client. `workspace-orchestrator` is a temporary compatibility alias for all its existing
subcommands (paths/check/ensure/watch/pump/install/event/projects/server-watch/daemon/dispatch);
`herdr-dispatchd` remains a daemon alias while host drop-ins still reference it. Old raw broker flags
and the legacy `dispatch --confirmed ...` worker command must not shadow the new global options.

Compatibility parsing is explicit: global skills/help/version take precedence. Legacy
health/snapshot/tasks/history/result/status/read/wait/dispatch spellings, with their original
`--socket` arguments, use the broker-client adapter; JSON stdout and existing exit semantics stay
unchanged, deprecation notices go only to stderr. `workspace-orchestrator dispatch <broker-op>`
maps to `herdr-dispatch broker <broker-op>`; its other subcommands map directly. Legacy
`--config` containing/ending in TOML gets a migration error, not reinterpretation as YAML.
Remove old raw ensure/event request-file mutation entrypoints from the public compatibility surface;
registered role operations require validated YAML and protocol v2. Health/history reads remain
available. No legacy ensure can recreate the reserved `orchestrator` name after cutover.

Normal JSON commands return 0 when their operation succeeds, 2 for usage/config errors, and 1 for
operation failure or an uncertain outcome (distinguished by structured error codes). Status reads
can succeed while an event is pending. CLI `event submit --wait --timeout` bounds total queue/hop
waiting (default 21600 seconds); it does not extend the task's registered execution timeout.
`event reconcile` and `event reconcile-readiness` are operator repair commands: require existing
receipt/artifact inspection, `--confirmed`, an appropriate `--decision` and a nonempty `--reason`.
No repair command may clear a claim to replay its handler or turn uncertain effects into success
without project evidence. Callback args use the existing stage-specific commands/choices.

## Stable roles and unique live names

| Role | Herdr live name | Required canonical cwd |
| --- | --- | --- |
| Computer-Orchestrator | `computer-orchestrator` | HERDR_COMPUTER_HOME |
| Project-Orchestrator | `project-orchestrator-<key>` | registered Git checkout root |

Herdr names must match `[a-z][a-z0-9_-]{0,31}`. The Project prefix is 21 characters, so the
explicit `orchestrator.key` must match `[a-z]([a-z0-9-]{0,9}[a-z0-9])?`. For `indiehackin-media`, use
`ih-media`, producing `project-orchestrator-ih-media` (29 characters). Full project IDs remain
independent of short keys. Never truncate or auto-hash a long ID, and never select an agent by
workspace label, tab position, current focus, or a reused pane ID. Names are derived and cannot be
overridden with a free-form `name` field.

Project IDs and short keys are unique within this manifest; derived names and canonical checkout
roots cannot collide. Two manifests sharing a server must not claim the same Computer role or
Project name at different roots. Runtime startup/prompt checks reject an existing wrong-cwd/kind
occupant; a matching name alone is not enough. Bind durable receipts to configured server,
computer ID, project ID, canonical cwd, kind, and native terminal generation.

Broker schema/protocol v2 records role ownership: computer/project ID, derived name, canonical cwd,
kind, manifest binding digest and native generation. A second manifest cannot claim an occupied
role with a different binding. Worker dispatch cannot use `computer-orchestrator`, the
`project-orchestrator-*` namespace or any registered role name; the broker checks this before
creation/adoption/prompting. This protects cooperative routing, not isolation from malicious code
running as the same OS user.

Retired role names in the migration map are also reserved against worker reuse while legacy
history/clients remain supported; they are historical lookup metadata, not live routing aliases.

One enabled project has one primary workspace; its human label is initial placement metadata.
Existing matching workspaces are reused. Project worktrees have distinct roots and need distinct
registered identities if independently managed; no routing through a parent checkout by accident.

## YAML v1

`start` ensures Computer and then each enabled Project role in `project_order`, an optional
top-level list containing every enabled project ID exactly once (otherwise alphabetical IDs).
It uses native Herdr protocol 22 move operations to place Computer home first, then managed
Project workspaces; each role's tab is first within its workspace. Existing matching sessions,
workers and terminal generations remain intact. `start --dry-run` previews roles without mutation.
The broker/default native server must be running. A layout conflict fails rather than moving
panes between workspaces. Startup may partially complete on an error; inspect before retrying.
Repeated starts reuse agents and do not submit business work. Launcher/model updates apply only
to newly started agents. For explicitly authorized YOLO startup, a role may configure
`launcher: [codex, --yolo]` and
`args: [--model, gpt-6.1-sol, -c, model_reasoning_effort=medium, -c, service_tier=fast]`.

The complete generic example is [projects.yaml.example](../config/workspace/projects.yaml.example).
One manifest owns computer startup intent, local transport, project roles and registered tasks.
Do not keep a second active registry in orchestrator.toml/projects.toml after migration.

```yaml
version: 1
computer:
  id: local-machine
  mode: standalone
  timezone: Asia/Taipei
  orchestrator:
    kind: codex
    args: []
transport:
  broker_socket: ~/.config/herdr-dispatchd/dispatch.sock
projects:
  indiehackin-media:
    enabled: true
    path: github/indiehackin-media
    workspace:
      label: indiehackin-media
    orchestrator:
      key: ih-media
      kind: codex
      launcher: [bash, scripts/codexyolo.sh]
      args: []
    tasks:
      transport-probe:
        entrypoint: [git, status, --short, --branch]
        timeout_seconds: 30
        scope: Read-only transport acceptance; no production or publication.
```

Field rules:

- Require `version: 1`, computer ID, computer kind, and a projects mapping. Reject duplicate YAML
  keys, unknown fields, multiple documents, custom tags, aliases/merge keys, and non-string argv.
  Computer ID is explicit and stable, not inferred from hostname. On a bound host, it must match
  the existing regular identity file; a mismatch fails rather than overwriting identity.
- `computer.orchestrator.kind` and project kind use the broker-supported kind allowlist and must
  be supported by the configured live Herdr server. `args` is an optional argv array, default `[]`;
  permit model/effort/service-tier arguments only for both roles. Each role's permission policy
  belongs to its explicitly configured executable `launcher` argv, not extra args.
  Never silently drop unsupported existing arguments during
  conversion; report them for host review. Preserve existing registered launchers.
- `transport.broker_socket` defaults to the existing local path above; an override is absolute or
  `~/`. YAML v1 supports the local default Herdr server only, at `~/.config/herdr/herdr.sock`.
  Custom Herdr sockets/sessions and remote selection are rejected until all call sites support
  them together. There is no assumed native server UUID: bind socket path, protocol, broker instance
  and terminal generation. Before a bridge mutates layout, its native Herdr role lookup must match
  the broker's role lookup/generation on that socket; a caller from another session is rejected.
- Optional `runtime`: `poll_seconds` (integer 10..300, default 30), `broker_state_dir`
  (default `~/.config/herdr-dispatchd`) and `execution_state_dir`
  (default `~/.local/state/workspace-orchestrator`). Preserve the existing state defaults through
  the executable rename; do not reset receipts or move state as an incidental config migration.
  All state paths are absolute or `~/`. Stale-caller lookup uses `runtime.broker_state_dir`, not
  the socket's parent directory. Computer `timezone` is an optional IANA name (default Asia/Taipei); trigger
  date/slot use this zone and are frozen once. Existing Taiwanese schedule/slot semantics stay intact.
- A project ID matches `[a-z][a-z0-9_-]{0,63}`. Require explicit boolean `enabled`, path, kind and
  short key. Disabled projects still validate schema/unique identity, but need not exist locally;
  submitting to them fails. Only enabled business projects count as managed projects.
- Resolve a relative project `path` from canonical Computer home; accept absolute or `~/` paths
  for checkouts outside Work. Require an existing directory whose `git rev-parse --show-toplevel`
  equals its canonical path, plus readable AGENTS.md and README.md. Reject category directories,
  nested subdirectories, relative paths escaping Computer home (including through symlinks), and
  duplicate canonical roots. An outside-Work path must be written explicitly as absolute or `~/` and is
  an explicit configured checkout; the broker allowlist permits that exact root, not its parent
  or the entire home directory. The Computer root is permitted for Computer operations only.
  Registered event/Project operations use this operation-specific policy. Legacy worker operations
  retain their explicitly authorized host root policy during compatibility; their broader roots
  cannot authorize an unregistered business-event route.
  An enabled project root must differ from Computer home. A project may have an empty tasks
  mapping for role presence only; no registered tasks means no business submissions to it.
- Launcher argv runs from the project root. argv[0] is a PATH command, absolute executable or
  checkout-relative executable path.
  A slash-containing relative executable is resolved within the checkout. Other path arguments
  (absolute, `~/`, slash-containing or existing files) must resolve inside the checkout; reject
  escapes. The system executable itself may live outside the repo. No embedded shell-command
  strings or implicit environment interpolation. Preserve existing registered launchers.
- Optional project `description` preserves delivery/ownership notes; task `scope` preserves
  authorization notes. These are descriptive, not grants to publish or bypass project gates.
- Optional workspace label is a nonempty display string; default project ID. It cannot select
  the dispatch target. Unknown Project names, absent/multiple matching roles and cwd/kind conflicts
  produce specific errors rather than rerouting to the Computer agent or another editor.
- Task IDs use the project ID grammar. Require nonempty `entrypoint` argv and `scope` string.
  Optional `verify_entrypoint` is nonempty argv; `timeout_seconds` is integer 1..7200, default 7200;
  `same_day` is boolean, default false; `input_env` is a unique array of environment variable names,
  default empty. `${date}`, `${slot}`, `${env:NAME}` are substituted as individual argv data only.
  Validate placeholders against supported inputs and the task's allowlist before submission.
  Names referenced by `${env:NAME}` are required (present and nonempty); other allowlisted names
  are optional and retain the existing empty-string behavior when absent. Use shell env-name
  grammar, valid UTF-8, no NUL, at most 8 KiB per input and 32 KiB total. Free text may include
  whitespace and is framed as data, not instructions or proof of permission. No secrets in inputs
  that enter prompts; no arbitrary YAML env expansion.
- Computer-only diagnostics are fixed built-in read-only probes, not YAML-defined arbitrary argv
  or business projects. Preserve historical diagnostic events and convert only recognized existing
  probe definitions. Do not introduce `internal: true` or a configurable diagnostic task registry
  that permits a business handler to bypass the Project hop. Address the built-in probe with
  `event submit --diagnostic read-only-probe --event-id <id>`, exclusive with project/task flags.
  Reserve the legacy `workspace-check` ID; preserve its history and translate only the recognized
  legacy read-only probe. Its payload has a diagnostic type and no Project route; business payloads
  require a Project route, and the broker enforces this distinction.

`check` reports resolved home/config, computer role, enabled project count, each resolved checkout
and derived agent name. `check` and `projects list` also report task IDs, scope, required/optional
input names, timeout and verifier presence; never current input values. Missing repos/instructions,
malformed task definitions and collisions
include the YAML field path. `check --live` adds native role/generation state and broker root-policy
compatibility. Neither command creates agents or submits work. Normal submission validates the
entire manifest and freezes computer ID/home, selected task, route, timezone/trigger inputs and
config digest before enqueue. Role RPCs validate the binding against the broker's loaded manifest.

### Host binding and instruction readiness

Require explicit `computer.mode`: `bound` for this existing dotfiles/idea deployment, or
`standalone` for a host without that deployment. A bound host cannot silently downgrade to
standalone to avoid its identity checks.

Bound mode has an optional `binding` mapping of absolute/`~/` `dotfiles_dir`, `idea_dir`,
`hosts_dir`, and `identity_file`, defaulting to the existing home layout (hosts defaults under the
resolved idea). Conversion copies actual existing non-default locations into this YAML; the new
runtime does not consult workspace.toml. Validate regular identity, selected private rules symlink
at Computer home, private ID/profile against actual OS, and managed Work AGENTS/README targets.
Keep the private registry's canonical source in those selected rules. Conflicting legacy root env
or a private-bound source presented as standalone fails deployment.

Standalone mode requires existing Computer-home AGENTS.md/README.md and the YAML's explicit
computer ID; no dotfiles/idea symlink or fleet inventory is required. It cannot auto-assign an ID
to an already bound host. Both modes validate registered project roots and instructions.

Readiness records bind role/name, computer/project ID, cwd, kind, terminal generation, relevant
normalized role-config digest and instruction digest. Bound Computer instructions include Work
AGENTS/README, selected private README/profile and common referenced orchestration rules;
standalone includes its Computer AGENTS/README. Project readiness includes repository AGENTS/README
and its role contract. Include the emitted skill/interface version and relevant YAML binding in
the role contract; TOML files are no longer digest inputs. The full manifest digest is audit/fencing
metadata; unrelated project additions do not invalidate a claimed handler whose frozen definition
and own route still match. During renaming, reset readiness to queued even if terminal ID survives.

## Skills output

`--skills` prints the complete built-in [SKILL.md](../tools/herdr-dispatch-rs/skills/herdr-dispatch/SKILL.md)
to stdout and exits 0, without resolving config or contacting services. Embed this one source
with Rust `include_str!`; no handwritten second help/skill registry. The output contains YAML
frontmatter and concise usage/receipt semantics. It does not expose machine inventories, credentials,
nonce values, live panes or host-specific config. Exporting text does not install a skill or create
directories. Agents can load it directly; a user/installer may explicitly save it as a discoverable
`herdr-dispatch/SKILL.md`. Normal implicit skill discovery is supported once installed.

## Dispatch and results

```text
Dagu -> herdr-dispatch event submit -> durable broker queue
 -> computer-orchestrator at Computer home: read rules, event ack, forward
 -> project-orchestrator-<key> at registered project root: read rules, project ack
 -> exclusive execution claim -> registered handler -> persisted Project result
 -> computer-orchestrator accepts correlated result -> Dagu completes -> artifact verifier
```

Presence is separate from business work. Reading AGENTS.md does not launch a service.
The service manager supervises broker/watch/server-watch; agents prove instruction readiness.
Computer cannot execute business handlers as a shortcut. Each hop retains a separate nonce,
generation/cwd checks, durable ack and frozen route. Preserve Project-only stale-caller fallback
with exact repo cwd, private second-hop capability and current native generation. Once a handler
is claimed, its callback can finish from the claim receipt even if the Project TUI disappears.

New Dagu events use `computer:workflow:run:project:task`, allowing different projects to register
the same logical task ID without collisions. Existing historical v1 keys retain their original
identity. The migration records a lookup mapping by computer/workflow/run/project/task for those
events; `--dagu` retries find the original event before generating a v2 key. Explicit ID retries
always keep the supplied ID. Ambiguous legacy lookup is an error, not a new execution. Completed events
return existing receipts. Busy roles queue work; blocked/wrong-cwd/wrong-kind roles receive no
prompt. Timeout/uncertain delivery or effects require inspection/reconciliation, never a new ID
or automatic replay. Artifact verification remains project-owned. Config enablement authorizes
role presence, not new publication permissions, topics, or external messages.

For completed historical events, a stable-ID retry after role renaming needs an explicit migration
mapping of old/new names to the same computer/project, cwd, kind and launcher. Compare frozen
logical task/inputs and handler definition, permitting only that recorded identity rename; return
the original immutable receipt without new prompts/claims. Different inputs or handler definitions
remain conflicts. Do not create live routing aliases or apply this rule to pending/uncertain events.
Normalize YAML defaults before comparing them to legacy definitions, rather than changing event
payloads merely because absent optional fields acquired defaults in the new parser.

## Ownership and migration

Public dotfiles owns Rust implementation, generic schema/example and embedded skill. Private
idea owns the actual per-computer projects.yaml and deployment intent. The default
`<Computer home>/projects.yaml` is a deployed link to that private source, not another editable
copy. Relative project paths stay based on Computer home even when the source link is in idea.
Credentials and runtime state stay local.

The TOML converter maps repo -> path, workspace_label -> workspace.label, delivery -> description,
and preserves task scope/argv/verifier/timeouts/input allowlists verbatim. Old orchestrator.name is
recorded in the explicit old-name/new-key migration map; no name truncation or implicit adoption.
The recognized internal workspace-check probe becomes the built-in diagnostic; other internal argv
is rejected for manual classification. Disabled entries retain metadata and are not dropped.
Normalize task defaults for definition digests at execute, verify, stale-context validation and
submit deduplication, while preserving historical JSON unchanged. Authorization scope is part of
that definition; descriptive project notes do not grant permissions.

Both broker startup and clients load the same validated YAML. Operation-specific `role_roots`
match exact canonical roots and ownership bindings; legacy `worker_roots` retain the separate,
explicitly authorized prefix policy. The legacy HERDR_DISPATCH_ALLOWED_ROOT setting cannot
silently override role policy. Check actual configured legacy worker roots during conversion.
All mutation RPCs carry protocol/binding epoch, computer ID, canonical Computer home and selected
role/task digests. Mismatches are rejected before ensure/prompt/claim. Changing unrelated projects
cannot invalidate an already claimed handler's matching frozen route and definition.

Every callback prefix explicitly supplies shell-quoted `HERDR_COMPUTER_HOME=<canonical root>` and
an absolute `herdr-dispatch --config <selected YAML>` path; it never relies on a split pane's env.
Dagu steps and service units likewise pin both values. Broker state lookup uses the configured
state directory. CLI rename changes immutable release filenames/install checks, aliases, paths
output and managed unit ExecStart, not only the Cargo bin name.

Migration sequence:

1. Prepare the YAML adapter, protocol/schema v2, strict validator, old CLI adapters, embedded skill
   and converter offline. Stage updated Work AGENTS/README/common/private role rules and bootstrap
   prompts naming the new roles; do not expose them to old live writers yet. Preserve project
   handlers, permission launchers and existing authorization notes. Actual local mode is bound.
2. Freeze new business submissions and pause future business/presence DAG starts. Drain existing
   events using the old compatible machinery before renaming anything; wait for complete DAG runs,
   including artifact verification, rather than only completed events. Resolve uncertain/claimed
   work from existing evidence. Inspect outstanding downstream producer handoffs that still store
   old parent names: completed dispatch is not completed production; rebind/reconcile these without
   restarting workers. Exact-ID observation/retry remains available; it cannot start new work.
3. Once drained, stop the old watch and broker services and confirm no old ensure/pump/presence
   writers or callback commands remain in flight. Keep the native Herdr server/agents running.
   Hold a local migration lock; save prior release/config/state pointers. No role rename occurs
   while an old writer can recreate its previous name.
4. Verify fresh live name/cwd/kind/generation, then native-rename the existing roles, preserving
   conversations and panes. Refuse occupied targets, blocked/busy roles or ambiguous inventory.
   Atomically convert the broker event/lifecycle store to schema 2, record role ownership and
   legacy ID/name mappings, retain completed event/claim/result JSON and reset readiness to queued.
   Old schema-1 broker must refuse schema 2 at startup; new broker refuses reserved legacy ensure
   names and missing v2 role-binding metadata. This fences mixed deployments.
5. Atomically expose the new immutable installed binary/YAML link and staged role rules. Rewrite
   broker/watch/presence/server-monitor units, Dagu commands, callbacks and host-owned project
   bindings such as editorial orchestrator_name. Source default Computer home solely from the new
   env/default, with explicitly pinned service/DAG/callback settings. Start the new broker/watch;
   server monitor updates preserve the healthy native server. Re-prove both roles' instruction
   readiness using name/binding/rules digests before reopening scheduled business submission.
6. Run readonly two-hop acceptance, same-ID legacy and v2 retries, cross-project same-task ID tests,
   wrong-cwd/kind/owner and duplicate-name rejections, custom Computer-home callback propagation,
   separate socket/state-directory tests, and optional-input migration tests. Verify one claim,
   unchanged native generations, Computer acceptance, full Dagu verification and no old-name
   duplicate agents. Restore schedules only after acceptance. Rollback must preserve any new
   claims/results; copying an old state snapshot back is not permission to replay effects.

Linux is the locally accepted deployment baseline. macOS monitor/broker LaunchAgents and safe
updates of loaded labels still need implementation and host acceptance; changing this interface
establishes neither another host's deployment nor reboot recovery.

## Opus 5.5 review resolution

The initial proposal was reviewed by an actual claude-opus-5-5 session on 2026-10-02. This revision
incorporates the findings as design requirements; it is not a deployed or code-tested v2 implementation.

- Findings 1-6: fence all old writers; complete command/alias contracts; reject TOML config ambiguity;
  pin callback/Dagu home/config; split exact role roots from legacy worker roots; preserve immutable
  history and normalized definition comparisons through full-DAG cutover.
- Findings 7-11: required versus optional inputs; explicit old-field mapping and notes; addressable
  fixed diagnostics; model/effort-only args with project-owned permissions; precise launcher paths.
- Findings 12-16: default Herdr transport only in v1; persisted role ownership and reserved names;
  project-qualified new event IDs with legacy lookup; configured state directory for fallback;
  bounded short keys and explicit timezone.
- Findings 17-20: name/config/instruction readiness; bound versus standalone validation; migrate
  deployed instructions/bootstrap prompts together; explicit legacy parsing and remove raw role
  mutation entrypoints from the normal CLI.
- Finding 21: skill authorization/maintenance boundaries, task discovery metadata, operator-only
  reconciliation, output/timeout semantics and real callback socket access without permission bypass.
