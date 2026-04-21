#!/usr/bin/env bash
# Create today's dated folder and a new session file seeded from template-session.md.
# Prints the path of the created session file on stdout so the caller can open/edit it.
# Usage: start_session.sh "<mission description>"

set -euo pipefail

SOURCE="${BASH_SOURCE[0]:-$0}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  LINK="$(readlink "$SOURCE")"
  case "$LINK" in
    /*) SOURCE="$LINK" ;;
    *)  SOURCE="$DIR/$LINK" ;;
  esac
done
SKILL_DIR="$(cd -P "$(dirname "$SOURCE")/.." && pwd)"

MISSION="${1:-untitled}"
AGENT="${LESSON_AGENT:-other}"
PROJECT="$(basename "$PWD")"
DATE="$(date +%Y-%m-%d)"
TIME_TAG="$(date +%H%M)"
TIME_ISO="$(date +%H:%M)"

# slug: lowercase, collapse non-alphanumerics to dashes, trim, cap length.
SLUG="$(printf '%s' "$MISSION" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
  | cut -c1-40)"
[ -z "$SLUG" ] && SLUG="mission"

ROOT="project-memory/lesson-learned"
DAY_DIR="$ROOT/$DATE"
SESSION_FILE="$DAY_DIR/session-$TIME_TAG-$SLUG.md"

if [ ! -f "project-memory/_CONTEXT.md" ]; then
  echo "No project-memory/ umbrella. Run bootstrap_memory.sh first." >&2
  exit 1
fi

mkdir -p "$DAY_DIR"

if [ ! -f "$DAY_DIR/_daily.md" ]; then
  sed -e "s|__DATE__|$DATE|g" -e "s|__PROJECT__|$PROJECT|g" \
    "$SKILL_DIR/references/template-daily.md" > "$DAY_DIR/_daily.md"
fi

if [ -f "$SESSION_FILE" ]; then
  # Collision: append a numeric suffix rather than overwrite.
  n=2
  while [ -f "$DAY_DIR/session-$TIME_TAG-$SLUG-$n.md" ]; do n=$((n+1)); done
  SESSION_FILE="$DAY_DIR/session-$TIME_TAG-$SLUG-$n.md"
fi

# Escape `|` in mission for sed's | delimiter.
MISSION_ESC="$(printf '%s' "$MISSION" | sed 's/|/\\|/g')"

sed -e "s|__DATE__|$DATE|g" \
    -e "s|__TIME__|$TIME_ISO|g" \
    -e "s|__PROJECT__|$PROJECT|g" \
    -e "s|__MISSION__|$MISSION_ESC|g" \
    -e "s|__AGENT__|$AGENT|g" \
    "$SKILL_DIR/references/template-session.md" > "$SESSION_FILE"

SESSION_NAME="$(basename "$SESSION_FILE")"
echo "| $TIME_ISO | $MISSION | (in progress) | [$SESSION_NAME](./$SESSION_NAME) |" >> "$DAY_DIR/_daily.md"

echo "$SESSION_FILE"
