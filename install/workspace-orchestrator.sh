#!/usr/bin/env bash
set -euo pipefail
dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bash "$dotfiles_dir/install/herdr-dispatch.sh"
"${HOME:?HOME is required}/.local/bin/workspace-orchestrator" install
