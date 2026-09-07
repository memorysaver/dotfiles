# Computer profiles

These are portable machine profiles, not an inventory of computers or deployed agents. Read only
the profile matching the destination computer; remote access does not change that computer's role.

- [mac.md](./mac.md): macOS workstation.
- [omarchy-desktop.md](./omarchy-desktop.md): user-facing Omarchy desktop.
- [omarchy-server.md](./omarchy-server.md): Omarchy server workstation.

Prefer the owner's explicit role declaration or the private host-management record. OS evidence
(`uname -s`, `/etc/omarchy-release`) identifies the platform, but a graphical session does not alone
distinguish an Omarchy desktop from a server workstation. SSH does not make a desktop a server.
If the role remains ambiguous, ask before making machine-specific changes.

General dispatch belongs in [workspace-rules](../workspace-rules/orchestrator.md). The old
[openab-orchestrator.md](./openab-orchestrator.md) path is only a compatibility reference.
Source: `~/.dotfiles/config/workspace/computer-rule/`. This index is the unbound fallback.
With a local computer ID, `~/Work/computer-rule` links to that computer's private rule directory;
its README references one public profile here. See `~/Work/README.md` for selection and sync.
