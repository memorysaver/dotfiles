#!/usr/bin/env bash
# Create today's dated folder and a new session file seeded from a template.
# Prints the path of the created session file on stdout so the caller can open/edit it.
#
# Usage:
#   start_session.sh --mode=<session|spec> [--continuous] "<mission description>"
#   start_session.sh --mode=session [--with-spec-axis] [--spec-ref=<pointer>] \
#                    [--continuous] "<mission description>"
#
# --mode is required. The agent picks it by reading the mission first; see
# workflows/start-session.md for the decision rule.
#
# --with-spec-axis appends Spec Reference / Deviations / Tradeoffs sections to
# the standard template. --spec-ref=<value> sets the spec_ref frontmatter field
# and implies --with-spec-axis. Both are rejected with --mode=spec (the spec
# template already has those sections).

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

MODE=""
CONTINUOUS=0
WITH_SPEC_AXIS=0
SPEC_REF=""

while [ $# -gt 0 ]; do
  case "$1" in
    --mode=*)         MODE="${1#--mode=}"; shift ;;
    --mode)           MODE="${2:-}"; shift 2 ;;
    --continuous)     CONTINUOUS=1; shift ;;
    --with-spec-axis) WITH_SPEC_AXIS=1; shift ;;
    --spec-ref=*)     SPEC_REF="${1#--spec-ref=}"; WITH_SPEC_AXIS=1; shift ;;
    --spec-ref)       SPEC_REF="${2:-}"; WITH_SPEC_AXIS=1; shift 2 ;;
    --) shift; break ;;
    --*) echo "Unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

if [ -z "$MODE" ]; then
  cat >&2 <<'ERR'
start_session.sh: --mode is required.

Pick the mode by reading the user's first message:
  --mode=spec     The user provided a written spec (PRD/RFC/ADR/design doc)
                  and the mission is to implement it. Capture deviations,
                  decisions, tradeoffs, and open questions.
  --mode=session  Everything else (refactor, debug, design, exploration,
                  extension). Standard nine-section template.

See workflows/start-session.md for the full decision rule.
ERR
  exit 2
fi

case "$MODE" in
  session) TEMPLATE="$SKILL_DIR/references/template-session.md" ;;
  spec)    TEMPLATE="$SKILL_DIR/references/template-spec-session.md"
           CONTINUOUS=1 ;;
  *) echo "Invalid --mode value: '$MODE' (must be session|spec)" >&2; exit 2 ;;
esac

if [ "$WITH_SPEC_AXIS" -eq 1 ] && [ "$MODE" = "spec" ]; then
  echo "start_session.sh: --with-spec-axis / --spec-ref are not valid with --mode=spec." >&2
  echo "The spec template already includes Spec Reference, Deviations, and Tradeoffs sections." >&2
  exit 2
fi

if [ "$CONTINUOUS" -eq 1 ]; then
  CAPTURE_MODE="continuous"
else
  CAPTURE_MODE="notable"
fi

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

# Escape `|` in mission and spec_ref for sed's | delimiter.
MISSION_ESC="$(printf '%s' "$MISSION" | sed 's/|/\\|/g')"
SPEC_REF_ESC="$(printf '%s' "$SPEC_REF" | sed 's/|/\\|/g')"

sed -e "s|__DATE__|$DATE|g" \
    -e "s|__TIME__|$TIME_ISO|g" \
    -e "s|__PROJECT__|$PROJECT|g" \
    -e "s|__MISSION__|$MISSION_ESC|g" \
    -e "s|__AGENT__|$AGENT|g" \
    -e "s|__CAPTURE_MODE__|$CAPTURE_MODE|g" \
    -e "s|__SPEC_REF__|$SPEC_REF_ESC|g" \
    "$TEMPLATE" > "$SESSION_FILE"

if [ "$WITH_SPEC_AXIS" -eq 1 ]; then
  # Insert Spec Reference / Deviations / Tradeoffs before ## Links.
  # If ## Links is missing for any reason, append at end.
  TMP="$(mktemp)"
  awk '
    BEGIN { inserted = 0 }
    /^## Links/ && !inserted {
      print "## Spec Reference"
      print "<!-- Link, path, or short title pointing to the spec. -->"
      print ""
      print "## Deviations"
      print "<!-- Places the implementation intentionally departs from the spec, and why."
      print "     If you followed the spec exactly, leave this empty — emptiness is the signal. -->"
      print ""
      print "## Tradeoffs"
      print "<!-- Alternatives considered and why the chosen one won."
      print "     Capture rejected paths too — future-you will want to know they were considered. -->"
      print ""
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print "## Spec Reference"
        print "<!-- Link, path, or short title pointing to the spec. -->"
        print ""
        print "## Deviations"
        print "<!-- Places the implementation intentionally departs from the spec, and why. -->"
        print ""
        print "## Tradeoffs"
        print "<!-- Alternatives considered and why the chosen one won. -->"
      }
    }
  ' "$SESSION_FILE" > "$TMP"
  mv "$TMP" "$SESSION_FILE"
fi

SESSION_NAME="$(basename "$SESSION_FILE")"
if [ "$MODE" = "spec" ]; then
  DAILY_MISSION="$MISSION (spec)"
else
  DAILY_MISSION="$MISSION"
fi
echo "| $TIME_ISO | $DAILY_MISSION | (in progress) | [$SESSION_NAME](./$SESSION_NAME) |" >> "$DAY_DIR/_daily.md"

echo "$SESSION_FILE"
