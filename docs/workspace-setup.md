# Workspace setup and maintenance

Read this only for installation, synchronization, link repair or migration.
The daily entrypoint is `~/Work/README.md`.

## Setup and updates

For a public installation, `just workspace` creates the directories and three links, using the
public computer-profile index until an identity is selected. Private installations select once:

```bash
just workspace-computer <computer-id>
just workspace
```

The ID comes from the private host-management index. It is stored only in
`~/.config/dotfiles/computer-id`, never in public dotfiles. Selection requires that computer's
`private-config/computers/<computer-id>/orchestration-rules/{README.md,profile}` to exist, and checks
that its profile matches this platform. It never guesses from hostname or the SSH client.
Each private directory owns its machine rules and agent references; common profiles stay in dotfiles.

For an already-bound computer with intact links, pull dotfiles and idea to update rule content;
no installer or rebinding is needed. Run `just workspace` only for initial adoption, link repair,
or an upgrade that explicitly changes deployed paths.
The persisted ID selects only that computer's rule directory. An unknown ID, missing private source,
or platform mismatch stops setup instead of silently using another computer's rules. Rebinding a
previously selected machine to a different ID is refused until the local identity is deliberately
reviewed and removed. A generic public symlink is upgraded automatically; foreign links and real
rule directories are preserved. `just unlink` retains the local ID for future reinstall.

`WORKSPACE_ROOT`, `WORKSPACE_ID_FILE`, and `WORKSPACE_HOSTS_DIR` can redirect the workspace setup
and identity resolver for isolated tests or custom private checkouts. They do not relocate the
application configs managed by `just link`.


Existing conflicting paths are preserved and cause setup to stop. Inspect them before explicitly
choosing the existing `DOTFILES_LINK_MODE=backup` migration option.

Update each computer's two source checkouts separately, preserving dirty changes. A symlink follows that computer's source checkout; it does not pull updates from Git.
Use `just link-dry-run` to inspect managed links and `just doctor` for the broader read-only health
check. `just unlink` removes managed workspace links but leaves repositories and real files intact.
Agent templates are seeded once; these operations do not synchronize live agent configuration.

Existing project migrations are deliberate per-repository work, governed by the dotfiles
`docs/workspace-migration.md` guide. Setup does not clone, move, or bulk-sync repositories.

Workspace link lifecycle regression check: `python tests/workspace-smoke.py` from dotfiles.

## Private idea checkout

The canonical private repository is `~/idea`, outside the project categories. It owns personal
concepts, research, and private configuration; each computer's rule directory references the public
baseline profiles under `~/.dotfiles`. Keep a dedicated Herdr workspace rooted at `~/idea` for its
work, and one at `~/.dotfiles` for public tooling work. Work-level orchestration routes by canonical
repository path, including these two repositories outside `~/Work`.

For an existing `~/Work/github/idea` checkout, inspect its instructions, Git status, worktrees and
any existing `~/idea` before an explicitly requested move. Preserve dirty work, repair linked Git
worktrees after moving, and retain the old path as a compatibility symlink while existing sessions
use it. Do not create a second clone or automatically delete the alias. New setups place the private
checkout directly at `~/idea`; workspace setup itself never clones it.

## Upgrade from separate rule directories

After updating both source checkouts, run `just workspace` with the existing local identity.
It creates the unified `orchestration-rules` link, then removes only the exact old managed
`computer-rule` and `workspace-rules` symlinks. Custom directories and foreign links are preserved
with a warning. Do not copy both old rule trees into the new one: private machine contents reference
the public profiles and shared dispatch procedures. Existing agent sessions must reread the new entry.
