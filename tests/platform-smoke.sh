#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

actual="$(bash -c 'source "$1/lib/helpers.sh"; printf "%s" "$DOTFILES_PLATFORM"' _ "$repo_root")"
[ -n "$actual" ] || { echo "platform detection returned empty" >&2; exit 1; }

for platform in macos omarchy arch debian; do
  detected="$(DOTFILES_PLATFORM="$platform" bash -c 'source "$1/lib/helpers.sh"; printf "%s" "$DOTFILES_PLATFORM"' _ "$repo_root")"
  [ "$detected" = "$platform" ] || {
    echo "platform override failed: expected $platform, got $detected" >&2
    exit 1
  }
done

echo "platform smoke test passed (host: $actual)"
