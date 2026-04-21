#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/agents/skills"

PASS=0
FAIL=0

ok() {
  printf '  [PASS] %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN { in_frontmatter = 0 }
    /^---$/ {
      if (in_frontmatter == 0) {
        in_frontmatter = 1
        next
      }
      exit
    }
    in_frontmatter == 1 && $0 ~ ("^" key ":") {
      sub("^" key ":[[:space:]]*", "", $0)
      gsub(/^"/, "", $0)
      gsub(/"$/, "", $0)
      print
      exit
    }
  ' "$file"
}

check_relative_links() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"

  while IFS= read -r ref; do
    case "$ref" in
      ""|http*|https*|\#*|mailto:*|app://*|plugin://*)
        continue
        ;;
    esac

    if [ ! -e "$dir/$ref" ]; then
      fail "$file references missing path: $ref"
    fi
  done < <(python3 - "$file" <<'PY'
import re
import sys

text = open(sys.argv[1], "r", encoding="utf-8").read()
for match in re.findall(r'\[[^]]+\]\(([^)]+)\)', text):
    print(match)
PY
)
}

check_forbidden_patterns() {
  local file="$1"
  local patterns=(
    "~/.claude/skills"
    "~/.codex/skills"
    "~/.pi/agent/skills"
    "/skill:"
  )
  local pattern

  for pattern in "${patterns[@]}"; do
    if grep -Fq "$pattern" "$file"; then
      fail "$file contains harness-specific pattern: $pattern"
    fi
  done
}

echo "=== Validating shared agent skills ==="

for skill_dir in "$SKILLS_DIR"/*; do
  [ -d "$skill_dir" ] || continue

  skill_name="$(basename "$skill_dir")"
  skill_file="$skill_dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    fail "$skill_name is missing SKILL.md"
    continue
  fi

  name_value="$(frontmatter_value "$skill_file" "name")"
  description_value="$(frontmatter_value "$skill_file" "description")"

  if [ -z "$name_value" ]; then
    fail "$skill_file is missing required frontmatter field: name"
  elif [ "$name_value" != "$skill_name" ]; then
    fail "$skill_file has name '$name_value' but directory is '$skill_name'"
  else
    ok "$skill_name frontmatter name matches directory"
  fi

  if [ -z "$description_value" ]; then
    fail "$skill_file is missing required frontmatter field: description"
  else
    ok "$skill_name has a description"
  fi

  check_relative_links "$skill_file"
  check_forbidden_patterns "$skill_file"
done

echo ""
echo "=== Skill validation summary: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
