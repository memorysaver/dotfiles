# Tailscale SSH + Herdr remote access

The intended Omarchy host baseline uses Tailscale SSH on port 22 for both
Herdr remote attach and SSH terminal access. Tailscale identity and the cloud
SSH policy authenticate connections; Moshi pairing keys are no longer needed.

## Recovery

1. Restore the usual dotfiles tools with `just setup-omarchy`.
2. Authenticate Tailscale on this host and enable Tailscale SSH:

   ```bash
   sudo tailscale up
   sudo tailscale set --ssh
   ```

3. Confirm a separate client can connect through Tailscale SSH before disabling
   any existing OpenSSH fallback. Keep the `openssh` package for its client.
4. Keep system `sshd.service` and any `sshd.socket` inactive and disabled.
   Remove Moshi-specific SSH drop-ins and explicit TCP 2222 firewall rules.
5. Keep UFW enabled with its incoming deny policy. No public port 22 or 2222
   allow rule or router forwarding is needed for this baseline. The former
   `tailscale0` TCP 2222 allow rule is retired as well.
6. Run `just audit-remote-access` to check the local baseline. Review the
   cloud-managed SSH policy separately; see the README's Tailnet SSH section.

## Connectivity checks

From another machine on the tailnet:

```bash
ssh <user>@<tailscale-host>
herdr --remote <user>@<tailscale-host>
```

Remove any client SSH alias or saved connection override that selects port
2222. Use Herdr remote attach from a normal terminal outside an existing Herdr
session. `tailscale ping` alone does not prove SSH login works. Tailscale SSH
is handled by `tailscaled`, so a kernel TCP 22 listener is not required.

## Ownership and history

Tailscale node identity, credentials, runtime state and cloud ACLs remain
outside this repository. Generic tools and this baseline are owned by dotfiles.

The 2026-08-29 setup added Moshi and an OpenSSH endpoint on port 2222 alongside
Tailscale SSH 22. Commit `8bd09c8` recorded its recovery procedure and example
policy. On 2026-09-08 the owner requested retiring that endpoint and retaining
Tailscale SSH only. The old recovery procedure remains in Git history; do not
reinstall its Moshi drop-in or pairing keys.
