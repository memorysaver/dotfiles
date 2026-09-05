#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
home_dir="${HOME:?HOME is required}"
bin_dir="$home_dir/.local/bin"
unit_dir="$home_dir/.config/systemd/user"
state_dir="$home_dir/.config/herdr-dispatchd"
crate_dir="$dotfiles_dir/tools/herdr-dispatch-rs"
release_dir="$crate_dir/target/release"

install -d -m 0700 "$bin_dir" "$unit_dir" "$state_dir"

if ! command -v cargo >/dev/null 2>&1; then
  printf 'cargo is required to build herdr-dispatch; run just runtimes first\n' >&2
  exit 1
fi

cargo build --release --locked --manifest-path "$crate_dir/Cargo.toml"

link_managed() {
  local source_path="$1"
  local target_path="$2"
  local legacy_path="${3:-}"
  if [[ -L "$target_path" && "$(readlink -f "$target_path")" == "$source_path" ]]; then
    return 0
  fi
  if [[ -L "$target_path" && -n "$legacy_path" && "$(readlink -f "$target_path")" == "$legacy_path" ]]; then
    rm "$target_path"
  fi
  if [[ -e "$target_path" || -L "$target_path" ]]; then
    printf 'Refusing to replace existing path: %s\n' "$target_path" >&2
    exit 1
  fi
  ln -s "$source_path" "$target_path"
}

link_managed \
  "$release_dir/herdr-dispatch" \
  "$bin_dir/herdr-dispatch"
link_managed \
  "$release_dir/herdr-dispatchd" \
  "$bin_dir/herdr-dispatchd"
link_managed "$dotfiles_dir/config/systemd/user/herdr-dispatchd.service" "$unit_dir/herdr-dispatchd.service"

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
