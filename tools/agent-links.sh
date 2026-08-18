#!/usr/bin/env bash
# Audit or migrate coding-agent config symlinks that point into this repo.
#
# Agent configs are machine-local by design (see README, "Agent Configs Are
# Machine-Local"). Machines set up before 2026-07-30 still have ~/.claude,
# ~/.codex, ~/.pi and ~/.config/opencode symlinked into the repo. `seed-agents`
# cannot fix those -- a symlink counts as "already exists" and gets skipped --
# so this is the one-shot migration.
#
# Usage:
#   agent-links.sh check   report only, exit 1 if anything still links here
#   agent-links.sh adopt   replace those links with real files, delete dead ones
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/helpers.sh"
set +e  # helpers.sh sets -e; we want to report every link, not die on the first

MODE="${1:-check}"
case "$MODE" in
  check|adopt) ;;
  *) fail "usage: agent-links.sh check|adopt"; exit 2 ;;
esac

# Config-bearing directories only. Each agent's own runtime state (debug logs,
# session transcripts, caches) has its own churn and is none of our business.
AGENT_DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/hooks"
  "$HOME/.claude/commands"
  "$HOME/.claude/skills"
  "$HOME/.claude/output-styles"
  "$HOME/.codex"
  "$HOME/.codex/skills"
  "$HOME/.pi/agent"
  "$HOME/.pi/agent/skills"
  "$HOME/.config/opencode"
)

# Every symlink directly inside those directories, deduplicated.
# A directory that is itself a symlink is skipped here: its parent's scan
# already reported it, and descending would list it a second time.
scan_links() {
  local dir
  for dir in "${AGENT_DIRS[@]}"; do
    [ -d "$dir" ] || continue
    [ -L "$dir" ] && continue
    find "$dir" -maxdepth 1 -type l 2>/dev/null
  done | sort -u
}

# Does this link point into the dotfiles repo?
points_here() {
  case "$1" in
    "$DOTFILES_DIR"/*|"$DOTFILES_DIR") return 0 ;;
    *) return 1 ;;
  esac
}

ours_live=0 ours_dead=0 foreign_dead=0 adopted=0 failed=0

while IFS= read -r link; do
  [ -n "$link" ] || continue
  target="$(readlink "$link")"

  if ! points_here "$target"; then
    # Someone else's link (the skills CLI, an agent's own installer). Not ours to touch.
    if [ ! -e "$link" ]; then
      warn "broken link, not ours: $link -> $target"
      foreign_dead=$((foreign_dead + 1))
    fi
    continue
  fi

  if [ ! -e "$link" ]; then
    ours_dead=$((ours_dead + 1))
    if [ "$MODE" = adopt ]; then
      rm "$link" && ok "removed dead link: $link -> $target"
    else
      warn "dead link into dotfiles: $link -> $target"
    fi
    continue
  fi

  ours_live=$((ours_live + 1))
  if [ "$MODE" = check ]; then
    warn "links into dotfiles: $link -> $target"
    continue
  fi

  # Dereference into place: copy the content, then swap it in.
  # -L follows the link, -p keeps the mode (statusline.sh needs +x,
  # codex/config.toml is 0600), -R handles output-styles being a directory.
  if cp -RLp "$link" "$link.__adopt__" 2>/dev/null; then
    rm -rf "$link" && mv "$link.__adopt__" "$link"
    ok "now a real file: $link"
    adopted=$((adopted + 1))
  else
    rm -rf "$link.__adopt__"
    fail "could not adopt, left as a link: $link -> $target"
    failed=$((failed + 1))
  fi
done < <(scan_links)

echo ""
if [ "$MODE" = check ]; then
  if [ "$((ours_live + ours_dead))" -eq 0 ]; then
    ok "No agent config links into this repo"
    [ "$foreign_dead" -gt 0 ] && warn "$foreign_dead broken link(s) owned by something else -- left alone"
    exit 0
  fi
  warn "$ours_live live link(s) and $ours_dead dead link(s) into this repo"
  warn "Agent configs are meant to be machine-local -- run \`just adopt-agents\` to fix"
  exit 1
fi

if [ "$((adopted + ours_dead))" -eq 0 ]; then
  ok "Nothing to adopt -- no agent config links into this repo"
else
  ok "Adopted $adopted file(s), removed $ours_dead dead link(s)"
  ok "These files are yours now; this repo will not write to them again."
fi
[ "$failed" -gt 0 ] && { fail "$failed link(s) could not be adopted"; exit 1; }
exit 0
