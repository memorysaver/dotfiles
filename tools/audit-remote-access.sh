#!/usr/bin/env bash
# Verify the Tailscale SSH + Herdr remote-access security baseline on this Omarchy host.
# Read-only: this script reports drift and never repairs configuration.

set -uo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat <<'EOF'
Usage: tools/audit-remote-access.sh
       just audit-remote-access

Checks the local security baseline for:
  - UFW enabled with deny-by-default inbound policy
  - no remaining UFW allow rule for retired TCP port 2222
  - Tailscale running with Tailscale SSH enabled
  - system OpenSSH disabled and TCP 2222 closed
  - Moshi installation and pairing state removed

The audit is read-only. It requests sudo so it can inspect the effective UFW
and service configuration. FAIL results produce exit status 1; warnings do not.
EOF
  exit 0
fi

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

PASS=0
WARN=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
soft() { WARN=$((WARN + 1)); printf '  \033[33m!\033[0m %s\n' "$*"; }
hard() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

TARGET_USER=${SUDO_USER:-${USER:-}}
if [[ -z $TARGET_USER || $TARGET_USER == root ]]; then
  hard "run this audit from the workstation user account, not a root login"
  TARGET_HOME=${HOME:-/root}
else
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
fi

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1 is installed"
  else
    hard "$1 is required for this audit"
  fi
}

head_ "Audit prerequisites"
for command_name in systemctl ufw ss tailscale jq; do
  require_command "$command_name"
done

head_ "Firewall"
if systemctl is-enabled --quiet ufw && systemctl is-active --quiet ufw; then
  pass "UFW is enabled and active"
else
  hard "UFW must be enabled and active"
fi

ufw_status=$(ufw status verbose 2>&1)
if grep -Fq 'Status: active' <<<"$ufw_status"; then
  pass "UFW runtime status is active"
else
  hard "UFW runtime status is not active"
fi

if grep -Eq 'Default: deny \(incoming\)' <<<"$ufw_status"; then
  pass "incoming traffic is deny-by-default"
else
  hard "UFW incoming policy is not deny-by-default"
fi

# The former Moshi endpoint must no longer have an explicit allow rule.
retired_rules=$(awk '
  $0 ~ /2222/ && $0 ~ /ALLOW IN/ { print }
' <<<"$ufw_status")
if [[ -z $retired_rules ]]; then
  pass "no UFW allow rule remains for TCP 2222"
else
  hard "retired port 2222 still has an ALLOW rule: ${retired_rules//$'\n'/; }"
fi

head_ "Tailscale"
if systemctl is-active --quiet tailscaled; then
  pass "tailscaled is active"
else
  hard "tailscaled is not active"
fi

tailscale_prefs=$(tailscale debug prefs 2>/dev/null || true)
if jq -e '.WantRunning == true' >/dev/null 2>&1 <<<"$tailscale_prefs"; then
  pass "Tailscale networking is enabled"
else
  hard "Tailscale networking is not enabled"
fi
if jq -e '.RunSSH == true' >/dev/null 2>&1 <<<"$tailscale_prefs"; then
  pass "Tailscale SSH remains enabled on port 22"
else
  hard "Tailscale SSH is disabled"
fi

tailscale_status=$(tailscale status --json 2>/dev/null || true)
if jq -e '.BackendState == "Running" and .Self.Online == true' >/dev/null 2>&1 <<<"$tailscale_status"; then
  pass "this device is online in its tailnet"
else
  hard "this device is not online in its tailnet"
fi
peer_count=$(jq -r '(.Peer // {}) | length' <<<"$tailscale_status" 2>/dev/null || printf '?')
soft "tailnet ACL/grants are cloud-managed and cannot be fully audited here; compare against the README section 'Tailnet SSH access policy' when device membership changes (currently $peer_count peer(s))"

head_ "Retired OpenSSH endpoint"
for unit in sshd.service sshd.socket; do
  if systemctl is-active --quiet "$unit" 2>/dev/null || systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    hard "$unit must be inactive and disabled"
  else
    pass "$unit is inactive and not enabled"
  fi
done
if listeners=$(ss -ltnH '( sport = :2222 )'); then
  if [[ -z $listeners ]]; then
    pass "TCP 2222 has no listener"
  else
    hard "TCP 2222 still has a listener"
  fi
else
  hard "cannot inspect TCP listeners"
fi

head_ "Moshi removal"
for path in "$TARGET_HOME/.local/bin/moshi" "$TARGET_HOME/.local/bin/moshi-hook" \
  "$TARGET_HOME/.config/moshi" "$TARGET_HOME/.local/state/moshi" \
  /etc/ssh/sshd_config.d/40-moshi-herdr.conf /etc/ssh/sshd_config.d/99-moshi-herdr.conf; do
  if [[ -e $path || -L $path ]]; then
    hard "retired Moshi path remains: $path"
  else
    pass "retired Moshi path absent: $path"
  fi
done
if [[ -f $TARGET_HOME/.ssh/authorized_keys ]] && grep -q 'moshi-pair:' "$TARGET_HOME/.ssh/authorized_keys"; then
  hard "a Moshi pairing key remains in authorized_keys"
else
  pass "no Moshi pairing key remains in authorized_keys"
fi

head_ "Summary"
printf '%d passed, %d warning(s), %d failed\n' "$PASS" "$WARN" "$FAIL"
if (( FAIL > 0 )); then
  printf '\033[31mRemote-access baseline has drifted.\033[0m\n' >&2
  exit 1
fi
printf '\033[32mRemote-access baseline is intact.\033[0m\n'
