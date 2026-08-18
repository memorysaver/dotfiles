#!/usr/bin/env bash
# Audit or migrate coding-agent config symlinks that point into this repo.
#
# Agent configs are machine-local by design (see README, "Agent Configs Are
# Machine-Local"). Machines set up before 2026-07-30 still have ~/.claude,
# ~/.codex, ~/.pi and ~/.config/opencode symlinked into the repo. `seed-agents`
# cannot fix those -- a symlink counts as "already exists" and gets skipped --
# so this is the one-shot migration.
#
# Skill links are handled the other way round: they are deleted, not dereferenced,
# because skills moved to per-project installs in the same era (see e94db6f).
#
# Usage:
#   agent-links.sh check   report only, exit 1 if anything still links here
#   agent-links.sh adopt   config links -> real files; skill links and dead links -> gone
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
CONFIG_DIRS=(
  "$HOME/.claude"
  "$HOME/.claude/hooks"
  "$HOME/.claude/commands"
  "$HOME/.claude/output-styles"
  "$HOME/.codex"
  "$HOME/.pi/agent"
  "$HOME/.config/opencode"
)

# Skills are installed per project since 2026-07-28 (see docs/agent-skills-sources.md).
# A link here is a leftover from the global-symlink era, so `adopt` deletes it rather
# than dereferencing it: copying would rebuild the global skill tree as real
# directories -- three duplicate copies of every skill -- which is the exact layout
# that migration dismantled.
SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.pi/agent/skills"
)

AGENT_DIRS=("${CONFIG_DIRS[@]}" "${SKILL_DIRS[@]}")

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

# Is this link inside one of the per-agent skill directories?
in_skill_dir() {
  local dir
  for dir in "${SKILL_DIRS[@]}"; do
    case "$1" in "$dir"/*) return 0 ;; esac
  done
  return 1
}

ours_live=0 ours_dead=0 foreign_dead=0 adopted=0 failed=0
skill_links=0 skill_removed=0

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

  # A global skill link: remove it, never dereference it. Plain `rm`, not `rm -rf` --
  # a symlink is one directory entry however big its target, and if the path somehow
  # is not a link we would rather fail than delete a real skill tree.
  if in_skill_dir "$link"; then
    skill_links=$((skill_links + 1))
    if [ "$MODE" = adopt ]; then
      if rm "$link" 2>/dev/null; then
        ok "removed global skill link: $link"
        skill_removed=$((skill_removed + 1))
      else
        fail "could not remove: $link -> $target"
        failed=$((failed + 1))
      fi
    else
      warn "global skill link: $link -> $target"
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
  if [ "$((ours_live + ours_dead + skill_links))" -eq 0 ]; then
    ok "No agent config or skill link points into this repo"
    [ "$foreign_dead" -gt 0 ] && warn "$foreign_dead broken link(s) owned by something else -- left alone"
    exit 0
  fi
  [ "$((ours_live + ours_dead))" -gt 0 ] &&
    warn "$ours_live live and $ours_dead dead config link(s) -- agent configs are meant to be machine-local"
  [ "$skill_links" -gt 0 ] &&
    warn "$skill_links global skill link(s) -- skills are installed per project now"
  warn "Run \`just adopt-agents\` to fix"
  exit 1
fi

if [ "$((adopted + ours_dead + skill_removed))" -eq 0 ]; then
  ok "Nothing to do -- no agent config or skill link points into this repo"
else
  [ "$((adopted + ours_dead))" -gt 0 ] &&
    ok "Adopted $adopted config file(s), removed $ours_dead dead config link(s)"
  [ "$skill_removed" -gt 0 ] &&
    ok "Removed $skill_removed global skill link(s) -- install skills per project with \`npx skills add\`"
  ok "Your configs are yours now; this repo will not write to them again."
fi
[ "$failed" -gt 0 ] && { fail "$failed link(s) could not be handled"; exit 1; }
exit 0
