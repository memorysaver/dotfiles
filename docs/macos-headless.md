# macOS Headless Remote Workstation

This document records the tested headless setup for the MacBook used as a
remote coding workstation. The primary target is:

```text
AC power + closed lid + Tailscale + OpenSSH + background processes
```

Status: tested on 2026-09-01. The BetterDisplay virtual-screen path remained
reachable during the observed closed-lid window. Long-duration, battery-
transition, and reboot tests are not a guarantee of future macOS behavior.

## Machine detected

| Item | Value |
| --- | --- |
| Model | 2023 MacBook Pro, `Mac14,9` |
| Chip | Apple M2 Pro |
| Memory | 32 GB |
| macOS | 26.3.1, build `25D2128` |
| FileVault | On |
| macOS firewall | On |
| BetterDisplay before setup | Not installed |
| Screen Sharing before setup | Not enabled |

## Existing remote-access baseline

Remote Login was already enabled through macOS. OpenSSH listens on the normal
macOS SSH port and is reached through the tailnet; Tailscale SSH itself remains
disabled (`RunSSH=false`). Do not expose this port to the public Internet.

The local verification used:

```bash
nc -G 2 -z 127.0.0.1 22
tailscale status --json
lsof -nP -iTCP:22 -sTCP:ESTABLISHED
```

From another tailnet machine, use ordinary SSH:

```bash
ssh -o ConnectTimeout=10 \
    -o ServerAliveInterval=30 \
    memorysaver@<herdr-tailscale-name>
```

Replace the host name with the name shown by `tailscale status`. This is
ordinary macOS OpenSSH transported over Tailscale, not Tailscale SSH.

## Power configuration

The battery policy was restored to normal idle sleep before the headless test.
The current relevant `pmset` values are:

| Setting | AC power | Battery | Reason |
| --- | ---: | ---: | --- |
| `sleep` | `0` | `10` | No idle system sleep on AC; normal battery sleep |
| `displaysleep` | `10` | `10` | Preserve display timeout |
| `disksleep` | `10` | `10` | Preserve disk timeout |
| `tcpkeepalive` | `1` | `1` | Preserve network wake behavior |
| `ttyskeepawake` | `1` | `1` | Keep terminal sessions eligible to stay awake |
| `womp` | `1` | `1` | Preserve network wake-on-demand behavior |
| `powernap` | `1` | `1` | Unchanged |
| `standby` | `1` | `1` | Unchanged |
| `hibernatemode` | `3` | `3` | Unchanged |
| `lowpowermode` | `1` | `1` | Unchanged |
| `networkoversleep` | `0` | `0` | Unchanged |

The exact current snapshot can be checked with:

```bash
pmset -g custom
pmset -g
```

No global `pmset disablesleep 1` setting was added. The `sleep=0` value alone
did not prevent Apple Silicon clamshell sleep in the first test; without a
virtual display, the power log recorded:

```text
Entering Sleep state due to 'Clamshell Sleep'
Entering Sleep state due to 'Maintenance Sleep'
```

## BetterDisplay setup

BetterDisplay is an optional GUI dependency. It is intentionally not part of
the default `just setup` path. The separate `just macos-headless-caffeinate`
recipe installs an opt-in user LaunchAgent for the additional sleep assertion;
it is also not part of the default setup.

Install the stable cask:

```bash
brew info --cask betterdisplay
brew install --cask betterdisplay
```

The tested installation was BetterDisplay `4.3.6`. The app passed both checks:

```bash
codesign --verify --deep --strict --verbose=2 \
  /Applications/BetterDisplay.app
spctl --assess --type execute --verbose=4 \
  /Applications/BetterDisplay.app
```

The result was a valid Developer ID signature and `source=Notarized Developer
ID`.

In BetterDisplay:

1. Open `Settings > Displays > Overview`.
2. Select `Create New Virtual Screen…`.
3. Choose the recommended `16:9` configuration.
4. Create it, then enable `Connect this virtual screen`.
5. Under `Settings > Application`, leave `Automatically launch on login`
   enabled.

The resulting display is named `Virtual 16:9` and currently reports:

```text
Online: Yes
Backing resolution: 5120 x 2880
UI Looks like: 2560 x 1440 @ 60.00Hz
```

This is the default 16:9 virtual screen, not a custom resolution list. The
exact free/Pro boundary can change between major versions; the current
[BetterDisplay feature matrix](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-pro-features)
lists virtual-screen creation and association as free, while custom virtual
screens and HDR virtual screens are Pro features. No Pro purchase was made for
this setup.

## Closed-lid verification

After the virtual screen was connected, the Mac was on AC and the lid was
closed. The observed state was:

- `AppleClamshellState = Yes`
- AC power, battery fully charged
- `Virtual 16:9` was the only Online display
- TCP port 22 remained reachable
- three existing OpenSSH sessions from a tailnet peer remained established
- Tailscale backend remained `Running` and Online
- no new `Entering Sleep state` or `Clamshell Sleep` event appeared during
  approximately 13 minutes of observation

The display log did contain `Display is turned off` and later `Display is
turned on` notifications. Those are display power events, not proof that the
whole operating system slept.

The observation was stopped manually. It was positive evidence that the
virtual display changes this Mac's closed-lid behavior, but it is not a formal
guarantee across macOS updates, thermal events, low battery, or reboot.

For future checks:

```bash
ioreg -r -k AppleClamshellState -d 1 | rg AppleClamshellState
pmset -g batt
pmset -g assertions
pmset -g log | rg 'Entering Sleep state|Wake from|DarkWake|Clamshell Sleep|Display is turned'
system_profiler SPDisplaysDataType
```

During this test, Codex and Music also had existing power assertions. Neither
BetterDisplay nor a new `caffeinate` process was holding the assertion, so the
result is encouraging but should still be treated as a local integration test,
not a standalone power-management proof.

## Caffeinate follow-up and battery transition

The initial positive observation did not survive a longer power-transition
test on the current MacBook. A temporary `/usr/bin/caffeinate -i -m -s`
process held both `PreventUserIdleSystemSleep` and `PreventSystemSleep` while
the machine was on AC, but the battery transition still followed macOS's
closed-lid policy:

```text
23:00:26  Using Batt
23:00:30  Entering Sleep state due to 'Clamshell Sleep'
23:00:57  Wake from Deep Idle ... USB-C_plug ... Using AC
23:03:34  Entering Sleep state due to 'Notification Wake Back to Sleep' ... Using Batt
23:04:31  Wake from Deep Idle ... USB-C_plug ... Using AC
```

The boot time did not change, so these events were sleep and wake rather than
a reboot or kernel panic. `caffeinate` is still useful for suppressing idle
and maintenance sleep while the Mac is on AC, but it is not a guarantee for
closed-lid battery operation on Apple Silicon. Keep the Mac powered for a
reliable headless session. If battery operation is required, leave the lid
open and turn the display off instead.

The helper is opt-in and can be applied with:

```bash
just macos-headless-caffeinate
```

It installs this user LaunchAgent:

```text
~/Library/LaunchAgents/com.memorysaver.macos-headless-caffeinate.plist
```

The plist runs `/usr/bin/caffeinate -i -m -s` and is kept alive by launchd.
The `-i` assertion also applies on battery, so it can increase battery drain;
the `-s` assertion is AC-specific. Check its status with:

```bash
launchctl print "gui/$(id -u)/com.memorysaver.macos-headless-caffeinate"
pmset -g assertions
```

## Reboot and security limits

- BetterDisplay is a login-session app, not a pre-login system daemon. It is
  configured to launch automatically after the user session starts.
- FileVault remains enabled. After a cold reboot, the Mac cannot provide a
  fully unattended graphical session while it is waiting for FileVault unlock.
- Remote Login and Tailscale may become available according to macOS boot and
  unlock state, but this was not validated through a reboot in this test.
- Screen Sharing was not enabled or tested. BetterDisplay is therefore not a
  substitute for enabling a remote GUI service.
- Do not disable FileVault, SIP, firewall protections, or SSH authentication
  controls to improve convenience.

## Rollback

Remove the virtual display before uninstalling the app:

1. Open BetterDisplay and select `Virtual 16:9`.
2. Turn off `Connect this virtual screen`.
3. Select `Discard…` and confirm removal.

Then uninstall the app if it is no longer wanted:

```bash
brew uninstall --cask betterdisplay
```

Disable the managed caffeinate helper with:

```bash
just macos-headless-caffeinate-off
```

The disable task removes only the LaunchAgent created by the dotfiles recipe;
it refuses to remove an unmanaged file at the same path.

The intended power configuration can be restored explicitly with:

```bash
sudo pmset -c sleep 0
sudo pmset -b sleep 10
```

The battery value must remain `10` for normal battery behavior. Restoring the
older pre-headless value of `0` would globally disable battery idle sleep and
is not recommended:

```bash
# Only if deliberately reverting the earlier battery-policy change:
sudo pmset -b sleep 0
```

## References

- [BetterDisplay project](https://github.com/waydabber/BetterDisplay)
- [Apple closed-display MacBook guidance](https://support.apple.com/en-au/102501)
- [Apple sleep and power-adapter guidance](https://support.apple.com/en-au/guide/mac-help/mchle41a6ccd/mac)
