#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT/agents/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
CODEX_SKILLS="$HOME/.codex/skills"
PI_SKILLS="$HOME/.pi/agent/skills"
PI_SETTINGS="$HOME/.pi/agent/settings.json"

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

check_skill_link() {
  local label="$1" root="$2" skill_name="$3" expected="$4"
  local link="$root/$skill_name"

  if [ ! -e "$root" ]; then
    fail "$label skill root is missing: $root"
    return
  fi

  if [ ! -L "$link" ]; then
    fail "$label is missing canonical symlink for $skill_name: $link"
    return
  fi

  local actual
  actual="$(cd "$(dirname "$link")" && cd "$(dirname "$(readlink "$link")")" && pwd -P)/$(basename "$(readlink "$link")")"
  expected="$(cd "$expected" && pwd -P)"

  if [ "$actual" = "$expected" ]; then
    ok "$label $skill_name link points to canonical source"
  else
    fail "$label $skill_name link points to $actual, expected $expected"
  fi
}

check_pi_settings() {
  if [ ! -f "$PI_SETTINGS" ]; then
    fail "Pi settings file is missing: $PI_SETTINGS"
    return
  fi

  python3 - "$PI_SETTINGS" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as file:
    settings = json.load(file)

skills = settings.get("skills")
if not isinstance(skills, list):
    raise SystemExit("skills must be an array")

if "~/.pi/agent/skills" not in skills:
    raise SystemExit("skills must include ~/.pi/agent/skills")

if settings.get("enableSkillCommands") is not True:
    raise SystemExit("enableSkillCommands must be true")
PY

  ok "Pi settings include canonical skills path"
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
  check_skill_link "Claude Code" "$CLAUDE_SKILLS" "$skill_name" "$skill_dir"
  check_skill_link "Codex" "$CODEX_SKILLS" "$skill_name" "$skill_dir"
  check_skill_link "Pi Agent" "$PI_SKILLS" "$skill_name" "$skill_dir"
done

check_pi_settings

echo ""
echo "=== Skill validation summary: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
