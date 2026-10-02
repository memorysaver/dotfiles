#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
home_dir="${HOME:?HOME is required}"
bin_dir="$home_dir/.local/bin"
unit_dir="$home_dir/.config/systemd/user"
state_dir="$home_dir/.config/herdr-dispatchd"
crate_dir="$dotfiles_dir/tools/herdr-dispatch-rs"
release_dir="$crate_dir/target/release"
libexec_dir="$home_dir/.local/libexec/workspace-orchestrator"
current_binary="$libexec_dir/current"

install -d -m 0700 "$bin_dir" "$unit_dir" "$state_dir"

if ! command -v cargo >/dev/null 2>&1; then
  printf 'cargo is required to build herdr-dispatch; run just runtimes first\n' >&2
  exit 1
fi

cargo build --release --locked --manifest-path "$crate_dir/Cargo.toml"

install -d -m 0700 "$libexec_dir/releases"
staging_dir="$(mktemp -d "$libexec_dir/.install.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
install -m 0755 "$release_dir/herdr-dispatch" "$staging_dir/herdr-dispatch"
binary_hash="$(sha256sum "$staging_dir/herdr-dispatch")"
binary_hash="${binary_hash%% *}"
version_dir="$libexec_dir/releases/$binary_hash"
if [[ -e "$version_dir" ]]; then
  cmp "$staging_dir/herdr-dispatch" "$version_dir/herdr-dispatch"
else
  mv "$staging_dir" "$version_dir"
fi
if [[ ! -e "$current_binary" && ! -L "$current_binary" ]]; then
  ln -s "$version_dir/herdr-dispatch" "$current_binary"
elif [[ ! -L "$current_binary" || "$(readlink "$current_binary")" != "$libexec_dir/releases/"*/workspace-orchestrator && "$(readlink "$current_binary")" != "$libexec_dir/releases/"*/herdr-dispatch ]]; then
  printf 'Refusing to replace unmanaged runtime: %s\n' "$current_binary" >&2
  exit 1
fi

link_managed() {
  local source_path="$1"
  local target_path="$2"
  local legacy_path="${3:-}"
  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    return 0
  fi
  if [[ -L "$target_path" ]] && {
    [[ -n "$legacy_path" && "$(readlink -f "$target_path")" == "$legacy_path" ]] ||
    [[ "$source_path" == "$current_binary" && "$(readlink -f "$target_path")" == "$release_dir/herdr-dispatch" ]];
  }; then
    ln -s "$source_path" "$target_path.next"
    mv -Tf "$target_path.next" "$target_path"
    return 0
  fi
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$target_path" >&2
    exit 1
  fi
  ln -s "$source_path" "$target_path"
}

link_managed \
  "$current_binary" \
  "$bin_dir/herdr-dispatch" "$release_dir/herdr-dispatch"
link_managed \
  "$current_binary" \
  "$bin_dir/herdr-dispatchd" "$release_dir/herdr-dispatchd"
# Preserve the previous managed Python launcher locally during migration.
if [[ -f "$bin_dir/workspace-orchestrator" && ! -L "$bin_dir/workspace-orchestrator" ]] && \
    rg -q '^# Managed by workspace-orchestrator$' "$bin_dir/workspace-orchestrator"; then
  install -d -m 0700 "$home_dir/.local/state/workspace-orchestrator/migration"
  cp -p "$bin_dir/workspace-orchestrator" \
    "$home_dir/.local/state/workspace-orchestrator/migration/launcher-$(date +%Y%m%d-%H%M%S)"
  ln -s "$current_binary" "$bin_dir/workspace-orchestrator.next"
  mv -Tf "$bin_dir/workspace-orchestrator.next" "$bin_dir/workspace-orchestrator"
fi
link_managed "$current_binary" "$bin_dir/workspace-orchestrator" "$release_dir/herdr-dispatch"
link_managed "$dotfiles_dir/config/systemd/user/herdr-dispatchd.service" "$unit_dir/herdr-dispatchd.service"

ln -s "$version_dir/herdr-dispatch" "$current_binary.next"
mv -Tf "$current_binary.next" "$current_binary"

systemctl --user daemon-reload
systemctl --user enable herdr-dispatchd.service
systemctl --user restart herdr-dispatchd.service
# systemd Type=simple may report active before the socket is bound. Check the
# broker locally without requiring Herdr itself to be online.
for attempt in {1..50}; do
  if "$bin_dir/herdr-dispatch" --socket "$state_dir/dispatch.sock" tasks >/dev/null 2>&1; then
    printf 'Rust herdr-dispatchd installed and ready\n'
    exit 0
  fi
  sleep 0.1
done
printf 'Broker did not become ready; inspect journalctl --user -u herdr-dispatchd.service\n' >&2
exit 1
