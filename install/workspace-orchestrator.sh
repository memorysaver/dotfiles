#!/usr/bin/env bash
set -euo pipefail
# A retirement is host-owned and must survive ordinary dotfiles updates.
if [[ -f "${HOME:?HOME is required}/.config/dotfiles/herdr-dispatch-retired" ]]; then
  printf 'herdr-dispatch is retired on this host; explicit rollback authorization is required.\n' >&2
  exit 1
fi
dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash "$dotfiles_dir/install/herdr-dispatch.sh"
"${HOME:?HOME is required}/.local/bin/workspace-orchestrator" install
