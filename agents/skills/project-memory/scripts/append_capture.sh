#!/usr/bin/env bash
# Append a timestamped bullet to a section of today's active session file.
# Usage: append_capture.sh <section> "<content>"
#   section: steering | failed | worked | takeaway | open

set -euo pipefail

SECTION="${1:-}"
CONTENT="${2:-}"
if [ -z "$SECTION" ] || [ -z "$CONTENT" ]; then
  echo "Usage: $0 <steering|failed|worked|takeaway|open> \"<content>\"" >&2
  exit 1
fi

case "$SECTION" in
  steering) HEADING="## Steering & Course Corrections" ;;
  failed)   HEADING="## What Failed / Frustrations" ;;
  worked)   HEADING="## What Worked" ;;
  takeaway) HEADING="## Takeaways" ;;
  open)     HEADING="## Open Questions" ;;
  *) echo "Unknown section: $SECTION (steering|failed|worked|takeaway|open)" >&2; exit 1 ;;
esac

DATE="$(date +%Y-%m-%d)"
TIME_ISO="$(date +%H:%M)"
DAY_DIR="project-memory/lesson-learned/$DATE"

if [ ! -d "$DAY_DIR" ]; then
  echo "No session folder for today ($DAY_DIR). Run start_session.sh first." >&2
  exit 1
fi

SESSION_FILE="$(ls -t "$DAY_DIR"/session-*.md 2>/dev/null | head -n1)"
if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then
  echo "No active session file in $DAY_DIR. Run start_session.sh first." >&2
  exit 1
fi

LINE="- [$TIME_ISO] $CONTENT"
TMP="$(mktemp)"

# Insert the bullet at the end of the target section (before the next '## ' heading
# or EOF). This keeps the template's comment hint at the top of the section intact.
awk -v heading="$HEADING" -v line="$LINE" '
  BEGIN { in_section = 0; inserted = 0 }
  {
    if ($0 == heading) {
      in_section = 1
      print
      next
    }
    if (in_section && /^## / && !inserted) {
      print line
      print ""
      print
      in_section = 0
      inserted = 1
      next
    }
    print
  }
  END {
    if (in_section && !inserted) {
      print line
    }
  }
' "$SESSION_FILE" > "$TMP"

mv "$TMP" "$SESSION_FILE"
echo "Appended to '$HEADING' in $SESSION_FILE"
