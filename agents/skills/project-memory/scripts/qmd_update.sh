#!/usr/bin/env bash
# Re-index all qmd collections. Safe no-op if qmd is not installed.
# qmd's `update` command has no per-collection flag; it re-indexes everything,
# which is fast because unchanged content hashes are skipped.

set -euo pipefail

if command -v qmd >/dev/null 2>&1; then
  qmd update >/dev/null 2>&1 || {
    echo "qmd update reported errors (non-fatal). rg fallback still works." >&2
    exit 0
  }
  echo "qmd index refreshed."
else
  echo "qmd not installed; skipping index refresh."
fi
