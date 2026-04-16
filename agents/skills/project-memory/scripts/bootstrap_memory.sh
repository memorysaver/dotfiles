#!/usr/bin/env bash
# Idempotent first-time setup for project-memory/ in the current project.
# Creates the umbrella folder (.gitignore + _CONTEXT.md), seeds the
# lesson-learned/ subsystem (_INDEX.md), and registers a qmd collection
# named "<project>-memory" scoped to the whole project-memory/ tree.
# Safe to re-run.

set -euo pipefail

# Resolve this script's real location even when invoked via symlink.
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

PROJECT="$(basename "$PWD")"
ROOT="project-memory"
LESSON_ROOT="$ROOT/lesson-learned"
COLLECTION="${PROJECT}-memory"

mkdir -p "$LESSON_ROOT"

# Umbrella files
if [ ! -f "$ROOT/.gitignore" ]; then
  cat > "$ROOT/.gitignore" <<'EOF'
# qmd sidecars (regenerable)
.qmd-cache/
*.sqlite
*.sqlite-shm
*.sqlite-wal
EOF
fi

if [ ! -f "$ROOT/_CONTEXT.md" ]; then
  sed "s|__PROJECT__|$PROJECT|g" "$SKILL_DIR/references/template-context.md" > "$ROOT/_CONTEXT.md"
fi

# lesson-learned subsystem
if [ ! -f "$LESSON_ROOT/_INDEX.md" ]; then
  sed "s|__PROJECT__|$PROJECT|g" "$SKILL_DIR/references/template-index.md" > "$LESSON_ROOT/_INDEX.md"
fi

# Register qmd collection for the whole umbrella.
if command -v qmd >/dev/null 2>&1; then
  if qmd collection show "$COLLECTION" >/dev/null 2>&1; then
    echo "qmd collection '$COLLECTION' already registered"
  else
    # qmd collection add uses cwd as the base, so we pass project-memory directly.
    qmd collection add project-memory --name "$COLLECTION" >/dev/null 2>&1 || {
      echo "Failed to register qmd collection. rg fallback will still work." >&2
    }
  fi
  qmd context add "qmd://$COLLECTION/" "$(cat "$ROOT/_CONTEXT.md")" >/dev/null 2>&1 || true
else
  echo "qmd not on PATH — skipping index registration. rg fallback will still work." >&2
fi

echo "Bootstrapped $ROOT (collection: $COLLECTION)"
