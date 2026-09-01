# Moshi + Herdr remote access

This is the recovery record for the Omarchy host that is reached over
Tailscale. It describes the deliberate two-path setup and the parts that must
remain machine-local.

## Current policy

| Use | Endpoint | Server | Authentication |
| --- | --- | --- | --- |
| Herdr remote attach | <tailscale-ip>:22 | Tailscale SSH | Tailscale identity and tailnet ACLs |
| Moshi | <tailscale-ip>:2222 | system OpenSSH (sshd) | one ED25519 public key; passwords and root login disabled |

The two rows are different products. “SSH over Tailscale” means ordinary
OpenSSH traffic routed through the Tailscale VPN. “Tailscale SSH” is Tailscale's
own SSH server and authentication path. Tailscale SSH uses port 22 on the
Tailscale interface; the normal sshd process is therefore kept on port 2222
for Moshi and any other ordinary SSH client.

Moshi does not inherently require port 2222. It needs normal OpenSSH key
authentication, and its usual default is port 22. Port 2222 exists here only
because port 22 is intentionally reserved for Tailscale SSH. If Tailscale SSH
is not used, Moshi can use ordinary sshd on its normal port instead.

See the [Moshi Tailscale guide](https://getmoshi.app/docs/tailscale) and
[Tailscale SSH documentation](https://tailscale.com/docs/features/tailscale-ssh)
for the distinction between these paths.

## What is tracked

- config/remote-access/sshd/99-moshi-herdr.conf.example is the non-secret
  OpenSSH policy.
- tools/audit-remote-access.sh and just audit-remote-access verify the
  firewall, Tailscale, sshd, and local file permissions without repairing
  anything.
- This document records the firewall rule and the reinstall order.

The following are intentionally not stored in Git:

- Tailscale node identity and interactive login state;
- tailnet ACLs/grants, which are managed in the Tailscale admin console;
- the actual ~/.ssh/authorized_keys and any private key;
- ~/.config/moshi/config.toml, which may contain machine-specific connection
  or credential data.

## Fresh Omarchy recovery

Run these steps on the machine that will host sshd and Moshi, not on the
client workstation. Start with the normal dotfiles setup:

~~~bash
cd ~/.dotfiles
just setup-omarchy
~~~

On a new installation, authenticate Tailscale interactively and enable
Tailscale SSH:

~~~bash
sudo tailscale up
sudo tailscale set --ssh
tailscale status
~~~

Install the tracked OpenSSH policy. Before restarting sshd, make sure there
is no other active system-OpenSSH Port 22 line; port 22 is reserved for
Tailscale SSH in this design.

~~~bash
sudo install -Dm644 \
  config/remote-access/sshd/99-moshi-herdr.conf.example \
  /etc/ssh/sshd_config.d/99-moshi-herdr.conf

sudo sshd -t
sudo sshd -T | awk '$1 == "port" { print }'
sudo systemctl enable --now sshd
sudo systemctl restart sshd
~~~

The effective configuration must include port 2222. If an existing
configuration still enables system OpenSSH on port 22, resolve that conflict
before restarting the service.

Keep the firewall limited to the Tailscale interface. Review the existing
rules first; the default deny command is appropriate for this baseline but
may not be appropriate for a host with other intentional inbound services.

~~~bash
sudo ufw status verbose
sudo ufw default deny incoming
sudo ufw allow in on tailscale0 to any port 2222 proto tcp
sudo ufw enable
~~~

Do not add a broad 2222/tcp ALLOW Anywhere rule and do not create a router
port-forward. Port 2222 is not made safe by being a nonstandard port; the
security boundary is Tailscale reachability, the interface-specific firewall
rule, key-only authentication, and the tailnet ACL.

Complete Moshi's interactive pairing/key setup on the host, then verify the
local permissions:

~~~bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.config/moshi
chmod 600 ~/.config/moshi/config.toml
~~~

Finally, run the read-only audit on this host:

~~~bash
just audit-remote-access
~~~

It is expected to report failures on a fresh host until Tailscale, sshd, the
firewall, Moshi, and the authorized key have all been restored.

## Connectivity checks

From another machine on the tailnet:

~~~bash
ssh <tailscale-ip>                         # Tailscale SSH / Herdr path
ssh -p 2222 <user>@<tailscale-ip>          # ordinary OpenSSH / Moshi path
~~~

Run herdr --remote from a normal terminal outside an existing Herdr session;
Herdr disables nested Herdr sessions by default. A tailscale ping only proves
Tailscale reachability; it does not prove that either SSH port is listening.
