#!/usr/bin/env bash
# Run Omarchy 4 ("Quattro") in a local VM on this Mac, installed from the official ISO.
#
# Why a VM and not a container: Hyprland's backend (Aquamarine) builds its
# allocator from the DRM backend, so it needs a card that does kernel
# modesetting. Docker/Colima expose no DRM device at all, and podman+libkrun
# exposes one that reports `KMS disabled` -- both die with "Cannot open backend:
# no allocator available". A QEMU VM with a plain 2D virtio-gpu is enough. That
# was verified here: no 3D at all (`features: -virgl`, `number of cap sets: 0`)
# but a connected connector, and Aquamarine logged `Created a GBM allocator`
# and drove a real DRM output rather than falling back to headless.
#
# Why the ISO and not the one-line web installer: `omarchy.org/install` runs
# boot.sh from the master branch, which is 3.8.5. Omarchy 4 lives on the
# `quattro` branch, and that branch ships no boot.sh and no install.sh at all
# (both are 404) -- for version 4 the ISO is the only fresh-install path. The
# upgrade path from 3.x is a separate script, `omarchy-upgrade-to-quattro`.
#
# Why raw QEMU and not lima: lima is built around cloud images and cloud-init.
# It has no way to boot an installer ISO, so nothing it offers applies here.
#
# Emulation cost: Apple Silicon cannot virtualise x86_64, and Omarchy publishes
# x86_64 only (https://pkgs.omarchy.org/stable/aarch64/omarchy.db is a 404, and
# its pacman.conf enables the x86-only [multilib]). So this runs under TCG.
# Measured on an M2 Pro: CPU work about 2x slower than a native VM, but booting
# is roughly 9x slower because kernel init is branch-heavy.
source "$(dirname "$0")/../lib/helpers.sh"

ISO_VERSION="${OMARCHY_ISO_VERSION:-4.0.0}"
ISO_URL="https://iso.omarchy.org/omarchy-${ISO_VERSION}.iso"
# Published by upstream in the v4.0.0 release notes, under "Install on new
# machines with the ISO". There is an omarchy-4.0.0.iso.sig next to the ISO too,
# but no public key is published at any obvious path, so this checksum is the
# only integrity check available.
ISO_SHA256="${OMARCHY_ISO_SHA256:-9224fab3720560f771969a99a499e5f7e0f8e2d6a0681d872d52f05fb5003da4}"

VM_DIR="${OMARCHY_VM_DIR:-$HOME/.local/share/omarchy-vm}"
ISO="$VM_DIR/omarchy-${ISO_VERSION}.iso"
DISK="$VM_DIR/disk.qcow2"
EFIVARS="$VM_DIR/efivars.fd"
PIDFILE="$VM_DIR/qemu.pid"
QMP="$VM_DIR/qmp.sock"
SERIAL="$VM_DIR/serial.log"

CPUS="${OMARCHY_VM_CPUS:-6}"
MEMORY="${OMARCHY_VM_MEMORY:-6G}"
DISK_SIZE="${OMARCHY_VM_DISK:-40G}"
VNC_DISPLAY="${OMARCHY_VM_VNC:-2}"   # :2 -> port 5902, clear of lima's 5900/5901
SSH_PORT="${OMARCHY_VM_SSH_PORT:-2222}"

# --- Prerequisites ---------------------------------------------------------

ensure_prereqs() {
  if [ "$DOTFILES_OS" != "macos" ]; then
    fail "This recipe is macOS-only. On Linux, boot the ISO with your own hypervisor."
    exit 1
  fi
  ensure_installed qemu-system-x86_64 qemu
  ensure_dir "$VM_DIR"

  FIRMWARE_DIR="$(brew --prefix)/share/qemu"
  if [ ! -f "$FIRMWARE_DIR/edk2-x86_64-code.fd" ]; then
    fail "No UEFI firmware at $FIRMWARE_DIR/edk2-x86_64-code.fd -- the ISO needs UEFI to boot."
    exit 1
  fi
}

# --- ISO -------------------------------------------------------------------

fetch_iso() {
  if [ -f "$ISO" ] && verify_iso quiet; then
    ok "ISO present and verified ($ISO_VERSION)"
    return 0
  fi

  info "Downloading Omarchy $ISO_VERSION (~6.3 GB, resumable)..."
  curl -fL --progress-bar -C - -o "$ISO" "$ISO_URL"

  if ! verify_iso; then
    fail "Checksum mismatch -- refusing to boot it. Delete $ISO and retry."
    exit 1
  fi
  ok "ISO verified"
}

verify_iso() {
  local actual; actual="$(shasum -a 256 "$ISO" | cut -d' ' -f1)"
  if [ "$actual" = "$ISO_SHA256" ]; then
    return 0
  fi
  [ "${1:-}" = quiet ] || { fail "expected $ISO_SHA256"; fail "actual   $actual"; }
  return 1
}

# --- VM --------------------------------------------------------------------

vm_running() {
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

start_vm() {
  if vm_running; then
    ok "VM already running (pid $(cat "$PIDFILE"))"
    return 0
  fi

  if [ ! -f "$DISK" ]; then
    info "Creating a $DISK_SIZE disk..."
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE" >/dev/null
  fi
  # OVMF needs a writable copy of the variable store; the one in the Homebrew
  # prefix is a read-only template shared by every VM on the machine.
  [ -f "$EFIVARS" ] || cp "$FIRMWARE_DIR/edk2-i386-vars.fd" "$EFIVARS"

  info "Booting (TCG emulation -- first boot off the ISO takes a few minutes)..."
  # Layout follows Omarchy's own documented Proxmox example: q35 + UEFI, virtio
  # disk, virtio GPU, both ISOs as CD-ROMs.
  #
  # `-boot order=cd` is c-then-d: hard disk first, CD-ROM second. On the first
  # boot the disk is empty so it falls through to the installer; afterwards the
  # installed system wins and the ISO is simply ignored. That is why the ISO can
  # stay attached and no reconfiguration is needed after installing.
  qemu-system-x86_64 \
    -name omarchy \
    -machine q35 \
    -accel tcg,thread=multi \
    -cpu max \
    -smp "$CPUS" \
    -m "$MEMORY" \
    -drive "if=pflash,format=raw,readonly=on,file=$FIRMWARE_DIR/edk2-x86_64-code.fd" \
    -drive "if=pflash,format=raw,file=$EFIVARS" \
    -drive "file=$DISK,if=virtio,format=qcow2,discard=on" \
    -drive "file=$ISO,media=cdrom,readonly=on" \
    -boot order=cd \
    -device virtio-vga \
    -device virtio-keyboard-pci \
    -device virtio-tablet-pci \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
    -device virtio-net-pci,netdev=net0 \
    -vnc "127.0.0.1:$VNC_DISPLAY" \
    -qmp "unix:$QMP,server,nowait" \
    -serial "file:$SERIAL" \
    -pidfile "$PIDFILE" \
    -daemonize

  ok "VM started (pid $(cat "$PIDFILE"))"
}

# --- Reporting -------------------------------------------------------------

vm_info() {
  printf '\n\033[1mConnect\033[0m\n'
  printf '  open vnc://127.0.0.1:%s\n' "$(( 5900 + VNC_DISPLAY ))"
  printf '  No VNC password -- the server is bound to loopback only.\n'

  printf '\n\033[1mFirst boot\033[0m\n'
  printf '  The Omarchy installer wizard runs on that screen: keyboard, timezone,\n'
  printf '  hostname, user, then the target disk. It reboots into the desktop itself.\n'
  printf '  Say no to disk encryption unless you want to type a LUKS passphrase at\n'
  printf '  every boot -- there is no keyboard attached until VNC is connected.\n'

  printf '\n\033[1mAfter install\033[0m\n'
  printf '  ssh -p %s <the user you created>@127.0.0.1\n' "$SSH_PORT"
  printf '  (Omarchy ships sshd disabled and the port closed; enable it in the VM first.)\n'

  printf '\n\033[1mFiles\033[0m\n'
  printf '  %s\n\n' "$VM_DIR"
}

vm_status() {
  if vm_running; then
    ok "running (pid $(cat "$PIDFILE")), VNC on 127.0.0.1:$(( 5900 + VNC_DISPLAY ))"
  else
    warn "not running"
  fi
  [ -f "$ISO" ]  && ok "ISO   $(du -h "$ISO"  | cut -f1)"  || warn "ISO not downloaded"
  [ -f "$DISK" ] && ok "disk  $(du -h "$DISK" | cut -f1) used of $DISK_SIZE" || warn "disk not created"
}

stop_vm() {
  if ! vm_running; then
    warn "not running"
    return 0
  fi
  info "Stopping..."
  kill "$(cat "$PIDFILE")" && rm -f "$PIDFILE"
  ok "Stopped"
}

# Unattended installs are supported by the ISO but not wired up here. It looks
# for a second drive labelled `cidata` holding the same files the wizard writes
# (user_configuration.json, user_credentials.json, optionally authorized_keys,
# user_full_name.txt, user_email_address.txt). Upstream publishes no schema for
# those files -- its own advice is to run one interactive install and copy what
# it wrote out of /root -- so guessing at them here would only produce installs
# that fail silently with nobody watching. Once you have a real set:
#
#   mkdir cidata && cp user_configuration.json user_credentials.json cidata/
#   hdiutil makehybrid -iso -joliet -default-volume-name cidata -o cidata.iso cidata/
#
# then add `-drive file=cidata.iso,media=cdrom,readonly=on` to the QEMU line.
# Note an encrypted install is never fully unattended: someone still has to type
# the LUKS passphrase on first boot.

# --- Entry point -----------------------------------------------------------

case "${1:-up}" in
  up)
    ensure_prereqs
    fetch_iso
    start_vm
    vm_info
    ;;
  info)    vm_info ;;
  status)  vm_status ;;
  stop)    stop_vm ;;
  destroy)
    stop_vm
    info "Removing the disk and UEFI variables (the ISO stays cached)..."
    rm -f "$DISK" "$EFIVARS" "$QMP" "$SERIAL"
    ok "Gone. Delete $ISO too if you want the 6.3 GB back."
    ;;
  *)
    fail "Usage: omarchy-vm.sh [up|info|status|stop|destroy]"
    exit 1
    ;;
esac
