#!/usr/bin/env bash
# Verify the Moshi + Herdr remote-access security baseline on this Omarchy host.
# Read-only: this script reports drift and never repairs configuration.

set -uo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
  cat <<'EOF'
Usage: tools/audit-remote-access.sh
       just audit-remote-access

Checks the local security baseline for:
  - UFW enabled with deny-by-default inbound policy
  - no public UFW allow rule for OpenSSH port 2222
  - Tailscale running with Tailscale SSH enabled
  - OpenSSH enabled on port 2222 with key-only authentication
  - SSH and Moshi key/config ownership and permissions

The audit is read-only. It requests sudo so it can inspect the effective UFW
and sshd configuration. FAIL results produce exit status 1; warnings do not.
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
for command_name in systemctl ufw sshd ss tailscale jq ssh-keygen; do
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

# A broad ALLOW for 2222 would expose OpenSSH on LAN/public interfaces. An
# interface-specific tailscale0 rule is compatible with this baseline.
public_2222_rules=$(awk '
  $0 ~ /2222\/tcp/ && $0 ~ /ALLOW IN/ && $0 !~ /tailscale0/ { print }
' <<<"$ufw_status")
if [[ -z $public_2222_rules ]]; then
  pass "no broad UFW allow rule exposes TCP 2222"
else
  hard "TCP 2222 has a non-Tailscale ALLOW rule: ${public_2222_rules//$'\n'/; }"
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

head_ "OpenSSH for Moshi and Herdr"
if systemctl is-enabled --quiet sshd && systemctl is-active --quiet sshd; then
  pass "sshd is enabled and active"
else
  hard "sshd must be enabled and active"
fi

if sshd -t; then
  pass "sshd configuration validates"
else
  hard "sshd configuration is invalid"
fi

sshd_effective=$(sshd -T 2>/dev/null || true)
check_sshd_value() {
  local key=$1 expected=$2
  if awk -v key="$key" -v expected="$expected" '
    tolower($1) == tolower(key) && tolower($2) == tolower(expected) { found=1 }
    END { exit !found }
  ' <<<"$sshd_effective"; then
    pass "sshd $key = $expected"
  else
    hard "sshd $key must be $expected"
  fi
}
if [[ -z $sshd_effective ]]; then
  hard "sshd -T returned no effective configuration"
fi
check_sshd_value port 2222
check_sshd_value pubkeyauthentication yes
check_sshd_value passwordauthentication no
check_sshd_value kbdinteractiveauthentication no
check_sshd_value permitrootlogin no

if ss -ltnH | awk '$4 ~ /:2222$/ { found=1 } END { exit !found }'; then
  pass "OpenSSH is listening on TCP 2222"
else
  hard "nothing is listening on TCP 2222"
fi

if ss -ltnH | awk '$4 ~ /:22$/ { found=1 } END { exit !found }'; then
  soft "a kernel listener also owns TCP 22; verify it is intentional (Tailscale SSH normally intercepts this in netstack)"
else
  pass "system OpenSSH is not listening on TCP 22"
fi

head_ "User SSH and Moshi state"
ssh_dir=$TARGET_HOME/.ssh
authorized_keys=$ssh_dir/authorized_keys

check_mode_owner() {
  local path=$1 expected_mode=$2
  if [[ ! -e $path ]]; then
    hard "$path is missing"
    return
  fi
  local actual_mode actual_owner
  actual_mode=$(stat -c '%a' "$path")
  actual_owner=$(stat -c '%U' "$path")
  if [[ $actual_mode == "$expected_mode" && $actual_owner == "$TARGET_USER" ]]; then
    pass "${path/#$TARGET_HOME/\~} is owned by $TARGET_USER with mode $expected_mode"
  else
    hard "${path/#$TARGET_HOME/\~} is $actual_owner mode $actual_mode; expected $TARGET_USER mode $expected_mode"
  fi
}

check_mode_owner "$ssh_dir" 700
check_mode_owner "$authorized_keys" 600

if [[ -r $authorized_keys ]]; then
  key_count=$(awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' "$authorized_keys")
  if [[ $key_count == 1 ]]; then
    pass "authorized_keys contains exactly one key"
  else
    hard "authorized_keys contains $key_count keys; baseline expects exactly one Moshi key"
  fi

  if awk 'NF && $1 !~ /^#/ && ($1 == "ssh-ed25519" || $2 == "ssh-ed25519") { found=1 } END { exit !found }' "$authorized_keys"; then
    pass "the authorized key uses ED25519"
  else
    hard "the authorized key is not ED25519"
  fi
fi

moshi_dir=$TARGET_HOME/.config/moshi
moshi_config=$moshi_dir/config.toml
check_mode_owner "$moshi_dir" 700
if [[ -f $moshi_config ]]; then
  config_mode=$(stat -c '%a' "$moshi_config")
  config_owner=$(stat -c '%U' "$moshi_config")
  if [[ $config_owner == "$TARGET_USER" && ( $config_mode == 600 || $config_mode == 644 ) ]]; then
    pass "~/.config/moshi/config.toml has expected ownership and safe mode $config_mode"
  else
    hard "~/.config/moshi/config.toml is $config_owner mode $config_mode; expected $TARGET_USER mode 600 or 644"
  fi
else
  hard "~/.config/moshi/config.toml is missing"
fi

head_ "Summary"
printf '%d passed, %d warning(s), %d failed\n' "$PASS" "$WARN" "$FAIL"
if (( FAIL > 0 )); then
  printf '\033[31mRemote-access baseline has drifted.\033[0m\n' >&2
  exit 1
fi
printf '\033[32mRemote-access baseline is intact.\033[0m\n'
