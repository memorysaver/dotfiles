# Verify the destination computer

Before machine-specific changes, local agent management or dispatch, check the destination itself:

1. Read `~/.config/dotfiles/computer-id` as a local regular file, not a symlink.
2. Resolve `~/Work/orchestration-rules` and confirm it equals the canonical directory
   `~/idea/private-config/computers/<computer-id>/orchestration-rules` for that exact ID.
3. Check that the selected README declares that ID and its `profile` file agrees with the
   declared profile. Compare with the actual OS (`uname -s`; on Linux inspect `/etc/os-release`
   and Omarchy installation evidence). `mac` requires macOS; Omarchy profiles require Omarchy.
   Server versus desktop is the explicitly selected role, not inferred from a GUI or SSH.

The shared fleet roster is a record, never proof of the current machine's identity. Hostnames,
remote clients, historical deployment notes and words such as “this computer” cannot override
these checks. If evidence is missing or inconsistent, stop identity-dependent changes and dispatch,
report the mismatch, and resolve it before proceeding. Do not overwrite identity or rebind to make
checks pass. Read-only diagnosis and unrelated project work can continue.

An intentionally unbound public installation has no private identity or inventory: confirm its
OS and owner-declared role before using a generic profile; do not assign a private computer ID.
Only setup or repair needs `~/.dotfiles/docs/workspace-setup.md`.
