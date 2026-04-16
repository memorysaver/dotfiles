#!/usr/bin/env bash
# Update _daily.md and _INDEX.md after a session wrap-up.
# Usage: update_index.sh <session-file>
#   - Parses frontmatter from <session-file>.
#   - Updates the matching row in _daily.md (outcome column).
#   - Appends a row to _INDEX.md's Session Log table.

set -euo pipefail

SESSION_FILE="${1:-}"
if [ -z "$SESSION_FILE" ]; then
  echo "Usage: $0 <session-file>" >&2
  exit 1
fi
if [ ! -f "$SESSION_FILE" ]; then
  echo "File not found: $SESSION_FILE" >&2
  exit 1
fi

INDEX="project-memory/lesson-learned/_INDEX.md"
if [ ! -f "$INDEX" ]; then
  echo "No $INDEX — run bootstrap_memory.sh first." >&2
  exit 1
fi

# Extract a top-level frontmatter field. Stops at the closing '---' marker.
get_field() {
  awk -v f="$1" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { exit }
    in_fm && $1 == f":" {
      sub(/^[^:]+:[[:space:]]*/, "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$SESSION_FILE"
}

DATE="$(get_field date)"
MISSION="$(get_field mission)"
OUTCOME="$(get_field outcome)"
[ -z "$OUTCOME" ] && OUTCOME="(unset)"
SESSION_BASENAME="$(basename "$SESSION_FILE")"
SESSION_NAME="${SESSION_BASENAME%.md}"
DAY_DIR="$(dirname "$SESSION_FILE")"
DAILY="$DAY_DIR/_daily.md"

# First takeaway bullet as the "key takeaway" column.
TAKEAWAY="$(awk '
  /^## Takeaways/ { flag = 1; next }
  /^## / && flag  { exit }
  flag && /^- /   { sub(/^- \[[0-9:]+\][[:space:]]*/, ""); sub(/^- /, ""); print; exit }
' "$SESSION_FILE")"
[ -z "$TAKEAWAY" ] && TAKEAWAY="(see session)"

# Update the matching _daily.md row's Outcome column (3rd pipe-separated field body).
if [ -f "$DAILY" ]; then
  TMP_DAILY="$(mktemp)"
  awk -v name="$SESSION_BASENAME" -v outcome="$OUTCOME" '
    BEGIN { FS = "|"; OFS = "|" }
    index($0, name) && /^\|/ {
      # Expected columns: "", " time ", " mission ", " outcome ", " file ", ""
      $4 = " " outcome " "
      print
      next
    }
    { print }
  ' "$DAILY" > "$TMP_DAILY"
  mv "$TMP_DAILY" "$DAILY"
fi

# Append row to _INDEX.md Session Log. The template leaves this table at EOF.
ROW="| $DATE | [$SESSION_NAME](./$DATE/$SESSION_NAME.md) | $MISSION | $OUTCOME | $TAKEAWAY |"

# Ensure file ends with a newline before appending.
[ -z "$(tail -c1 "$INDEX")" ] || printf '\n' >> "$INDEX"
printf '%s\n' "$ROW" >> "$INDEX"

echo "Updated $DAILY and appended row to $INDEX"
