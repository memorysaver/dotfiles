#!/usr/bin/env bash
source "$(dirname "$0")/../lib/helpers.sh"

expected="${1:-}"
[ -n "$expected" ] || { fail "Usage: platform-check.sh <platform>"; exit 2; }

if [ "$DOTFILES_PLATFORM" != "$expected" ]; then
  fail "This recipe is for $expected, but detected $DOTFILES_PLATFORM"
  exit 1
fi

ok "Detected platform: $DOTFILES_PLATFORM"
