# Orchestration rules

This is the single rules entrypoint for an independent computer. Public installations use this
shared directory. A selected computer links `~/Work/orchestration-rules` to its private directory
under `~/idea/private-config/computers/<computer-id>/orchestration-rules`; its README references
the appropriate common documents here without copying them or publishing its agent inventory.

Load only what the task needs:

- Machine-specific work: read the matching profile under [profiles](./profiles/README.md).
- Work management and Herdr dispatch: read [orchestrator.md](./orchestrator.md).
- External service using the broker: also read [external-dispatch.md](./external-dispatch.md).
- Direct project implementation: follow that repository's nearest instructions.

Select a private computer identity with `just workspace-computer <computer-id>`, then run
`just workspace`. If unbound, identify the destination machine's role before machine-specific
changes; do not infer it from the remote client, an SSH connection, or the mere presence of a GUI.
See `~/Work/README.md` for setup and synchronization. Credentials and runtime state remain local.
