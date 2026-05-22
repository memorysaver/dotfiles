#!/usr/bin/env bash
# Widen an active spec-mode session into the standard session shape.
# Additive only — preserves all existing content.
#
# Usage: promote_to_session.sh [--session-file=<path>]
#
# Default target: today's most recently modified session-*.md under
# project-memory/lesson-learned/<today>/.
#
# Behavior:
#   - Idempotent: if the target is already mode: session, prints a message
#     and exits 0.
#   - Rewrites mode: spec -> mode: session in frontmatter. Keeps capture_mode
#     and spec_ref untouched.
#   - Inserts the missing standard sections (Mission, Prompt Evolution,
#     Steering, What Worked, What Failed, Skills & Tools, Takeaways,
#     Candidates for memory save) immediately before ## Open Questions, so
#     the spec-axis cluster stays together at the top.
#   - Updates the matching row in _daily.md: " (spec)" -> " (spec→session)".

set -euo pipefail

SESSION_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --session-file=*) SESSION_FILE="${1#--session-file=}"; shift ;;
    --session-file)   SESSION_FILE="${2:-}"; shift 2 ;;
    --) shift; break ;;
    --*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

if [ -z "$SESSION_FILE" ]; then
  DATE="$(date +%Y-%m-%d)"
  DAY_DIR="project-memory/lesson-learned/$DATE"
  if [ ! -d "$DAY_DIR" ]; then
    echo "No session folder for today ($DAY_DIR). Pass --session-file=<path>." >&2
    exit 1
  fi
  SESSION_FILE="$(ls -t "$DAY_DIR"/session-*.md 2>/dev/null | head -n1)"
  if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then
    echo "No active session file in $DAY_DIR. Pass --session-file=<path>." >&2
    exit 1
  fi
fi

if [ ! -f "$SESSION_FILE" ]; then
  echo "Session file not found: $SESSION_FILE" >&2
  exit 1
fi

CURRENT_MODE="$(awk '/^mode:/ { print $2; exit }' "$SESSION_FILE")"
if [ "$CURRENT_MODE" = "session" ]; then
  echo "Already mode: session — nothing to promote: $SESSION_FILE"
  exit 0
fi
if [ "$CURRENT_MODE" != "spec" ]; then
  echo "Cannot promote: unexpected mode '$CURRENT_MODE' in $SESSION_FILE" >&2
  exit 1
fi

TMP="$(mktemp)"

# Rewrite frontmatter mode and insert missing standard sections before ## Open Questions.
awk '
  BEGIN { in_frontmatter = 0; frontmatter_seen = 0; inserted = 0 }
  NR == 1 && /^---$/ { in_frontmatter = 1; print; next }
  in_frontmatter && /^---$/ { in_frontmatter = 0; frontmatter_seen = 1; print; next }
  in_frontmatter && /^mode: spec[[:space:]]*$/ { print "mode: session"; next }
  /^## Open Questions/ && !inserted && frontmatter_seen {
    print "## Mission"
    print "<!-- What the user was trying to accomplish. Context. Why now. -->"
    print ""
    print "## Prompt Evolution"
    print "<!-- Ordered list of how the user'\''s ask shifted across turns."
    print "     Each entry: 1-line prompt summary + 1-line commentary on why it shifted. -->"
    print ""
    print "## Steering & Course Corrections"
    print "<!-- Moments the user redirected: what the agent did, what the user said, why. -->"
    print ""
    print "## What Worked"
    print "<!-- Concrete wins with enough context to reproduce. -->"
    print ""
    print "## What Failed / Frustrations"
    print "<!-- What went wrong. Root cause if known. Dead ends tried. -->"
    print ""
    print "## Skills & Tools Involved"
    print "| Name | Role | Quality | Quirks |"
    print "| ---- | ---- | ------- | ------ |"
    print ""
    print "## Takeaways"
    print "<!-- Concrete heuristics future sessions should carry. Prefer testable rules over vibes. -->"
    print ""
    print "## Candidates for memory save"
    print "<!-- Draft entries for ~/.claude/projects/.../memory/. User approves before write."
    print "     Format: `type: feedback | name: snake_case | body: \"...\"` -->"
    print ""
    inserted = 1
  }
  { print }
' "$SESSION_FILE" > "$TMP"

mv "$TMP" "$SESSION_FILE"

# Update _daily.md row suffix.
DAY_DIR="$(dirname "$SESSION_FILE")"
DAILY="$DAY_DIR/_daily.md"
SESSION_NAME="$(basename "$SESSION_FILE")"
if [ -f "$DAILY" ]; then
  TMP="$(mktemp)"
  awk -v sfile="$SESSION_NAME" '
    index($0, "[" sfile "]") > 0 {
      sub(/ \(spec\) \|/, " (spec→session) |")
    }
    { print }
  ' "$DAILY" > "$TMP"
  mv "$TMP" "$DAILY"
fi

echo "Promoted to session mode: $SESSION_FILE"
