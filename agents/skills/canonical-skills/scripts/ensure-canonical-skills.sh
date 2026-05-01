#!/usr/bin/env bash
# ensure-canonical-skills.sh — converge a project to the canonical layout used
# by the canonical-skills skill (see SKILL.md alongside this script).
#
# Invariants enforced (per project):
#   1. <project>/skills/                         — real directory, source of truth
#   2. <project>/.claude/skills -> ../skills     — symlink for Claude Code
#   3. <project>/.agents/skills -> ../skills     — symlink for Codex / agents.md tooling
#   4. <project>/AGENTS.md                       — canonical agent guide (real file)
#   5. <project>/CLAUDE.md                       — contains exactly `@AGENTS.md`
#
# Usage:
#   bash ensure-canonical-skills.sh                 # current directory
#   bash ensure-canonical-skills.sh /path/to/proj   # specific project
#   bash ensure-canonical-skills.sh --dry-run       # preview, no changes
#   bash ensure-canonical-skills.sh --help
#
# The script is idempotent — re-running on an already-canonical project prints
# only "already canonical" and exits 0. Refusals are per-step, so a divergent
# AGENTS.md doesn't prevent the .claude/skills symlink from being created (or
# vice versa). The script exits non-zero if any step refused.

set -euo pipefail

show_help() {
  cat <<'HELP'
Usage: bash ensure-canonical-skills.sh [OPTIONS] [PROJECT_PATH]

Converge a project to the canonical layout shared by Claude Code, Codex, and
Pi Agent:

  <project>/skills/                  (real directory)
  <project>/.claude/skills           → symlink to ../skills
  <project>/.agents/skills           → symlink to ../skills
  <project>/AGENTS.md                (canonical agent guide)
  <project>/CLAUDE.md                (contains: @AGENTS.md)

Options:
  --dry-run    Preview changes without modifying files
  --help       Show this help message

Arguments:
  PROJECT_PATH  Directory to operate on. Defaults to the current directory.

The script is idempotent — re-running on an already-canonical project is a no-op.
HELP
}

# --- Parse args ---

DRY_RUN=false
PROJECT_PATH=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h) show_help; exit 0 ;;
    --*) echo "Unknown option: $arg" >&2; echo "Run with --help for usage." >&2; exit 1 ;;
    *)
      if [ -n "$PROJECT_PATH" ]; then
        echo "Unexpected extra argument: $arg" >&2
        exit 1
      fi
      PROJECT_PATH="$arg"
      ;;
  esac
done

if [ -z "$PROJECT_PATH" ]; then
  PROJECT_PATH="$(pwd)"
fi

# Expand ~ if user provided one.
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if [ ! -d "$PROJECT_PATH" ]; then
  echo "ERROR: not a directory: $PROJECT_PATH" >&2
  exit 1
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd -P)"

# --- Helpers (modeled on migrate-downstream-layout.sh:115-140) ---

# Resolve a path's canonical real path. Echo empty if it doesn't resolve.
# Only handles directories and symlinks; callers don't need this for plain files.
real_path() {
  local p="$1"
  if [ -L "$p" ] || [ -d "$p" ]; then
    (cd "$p" 2>/dev/null && pwd -P) || echo ""
  else
    echo ""
  fi
}

is_git_repo() {
  git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1
}

git_tracked() {
  # Args: <repo-relative path>. Echoes "yes" if tracked, else "no".
  local rel="$1"
  if git -C "$PROJECT_PATH" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
    echo "yes"
  else
    echo "no"
  fi
}

# Run a command, or echo it as a "would do" line under --dry-run.
do_or_preview() {
  local label="$1"; shift
  if [ "$DRY_RUN" = true ]; then
    echo "    Would $label"
  else
    "$@"
    echo "    $label"
  fi
}

# --- Pre-flight ---

echo "ensure-canonical-skills"
echo "  project: $PROJECT_PATH"
if [ "$DRY_RUN" = true ]; then
  echo "  mode: dry-run"
fi
echo ""

GIT_REPO=no
if is_git_repo; then
  GIT_REPO=yes
  branch="$(git -C "$PROJECT_PATH" symbolic-ref --short HEAD 2>/dev/null || echo '')"
  if [ -n "$(git -C "$PROJECT_PATH" status --porcelain 2>/dev/null)" ]; then
    echo "REFUSE: working tree has uncommitted changes (commit or stash first so the migration is one reviewable diff)" >&2
    exit 2
  fi
  echo "  git: yes (branch: ${branch:-detached})"
else
  echo "  git: no — running with plain mv/cp (no history preservation)"
fi
echo ""

REFUSED=0
CHANGES=0

# --- Step 1: <project>/skills/ ---

echo "Step 1: <project>/skills/"
CANONICAL="$PROJECT_PATH/skills"

if [ -L "$CANONICAL" ]; then
  echo "  REFUSE: <project>/skills is itself a symlink — manual review required" >&2
  echo "    target: $(readlink "$CANONICAL")" >&2
  REFUSED=$((REFUSED + 1))
elif [ -d "$CANONICAL" ]; then
  echo "  OK — already a real directory"
  if [ -z "$(find "$CANONICAL" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "  Would create skills/.gitkeep for empty skills directory"
    else
      : > "$CANONICAL/.gitkeep"
      [ "$GIT_REPO" = "yes" ] && ( cd "$PROJECT_PATH" && git add skills/.gitkeep )
      echo "  created skills/.gitkeep"
    fi
    CHANGES=$((CHANGES + 1))
  fi
else
  if [ "$DRY_RUN" = true ]; then
    echo "  Would create skills/ with .gitkeep"
  else
    mkdir -p "$CANONICAL"
    : > "$CANONICAL/.gitkeep"
    [ "$GIT_REPO" = "yes" ] && ( cd "$PROJECT_PATH" && git add skills/.gitkeep )
    echo "  created skills/ with .gitkeep"
  fi
  CHANGES=$((CHANGES + 1))
fi
echo ""

# --- Step 2: runtime project skill symlinks -> ../skills ---

ensure_runtime_skills_link() {
  local runtime_dir="$1"
  local link_rel="$2"
  local display="$3"
  local link_path="$PROJECT_PATH/$link_rel"
  local parent_rel
  parent_rel="$(dirname "$link_rel")"
  local parent_path="$PROJECT_PATH/$parent_rel"

  echo "$display"

  create_runtime_symlink() {
    if [ "$DRY_RUN" = true ]; then
      echo "  Would create symlink $link_rel → ../skills"
      return 0
    fi
    mkdir -p "$parent_path"
    ( cd "$parent_path" && ln -s ../skills skills )
    [ "$GIT_REPO" = "yes" ] && ( cd "$PROJECT_PATH" && git add "$link_rel" )
    echo "  created symlink $link_rel → ../skills"
  }

  if [ -L "$link_path" ]; then
    link_target="$(cd "$parent_path" 2>/dev/null && cd "$(readlink skills)" 2>/dev/null && pwd -P || echo "")"
    if [ "$link_target" = "$CANONICAL" ]; then
      echo "  OK — already symlinked to ../skills"
    else
      echo "  REFUSE: $link_rel is a symlink pointing elsewhere ($link_target)" >&2
      echo "    Remove it manually if intentional, then re-run." >&2
      REFUSED=$((REFUSED + 1))
    fi
  elif [ ! -e "$link_path" ]; then
    create_runtime_symlink
    CHANGES=$((CHANGES + 1))
  elif [ -d "$link_path" ]; then
    # Real directory. Move entries into skills/ then replace with symlink.
    # Conflict pre-check: any entry that exists at both <runtime>/skills/<X> and
    # skills/<X> with different content is a hard refusal for this step.
    conflicts=()
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      src="$link_path/$entry"
      dst="$CANONICAL/$entry"
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        # Same target after resolution = no conflict (one already points at the other).
        d_real="$(real_path "$dst")"
        s_real="$(real_path "$src")"
        if [ -n "$d_real" ] && [ "$d_real" = "$s_real" ]; then
          continue
        fi
        # Diff-equal also = no conflict.
        if diff -rq "$src" "$dst" >/dev/null 2>&1; then
          continue
        fi
        conflicts+=("$entry")
      fi
    done < <(ls -A "$link_path" 2>/dev/null)

    if [ "${#conflicts[@]}" -gt 0 ]; then
      echo "  REFUSE: $link_rel/ has entries that conflict with skills/:" >&2
      for c in "${conflicts[@]}"; do
        echo "    - $c (different content on each side)" >&2
      done
      echo "  Resolve manually (delete the unwanted side under skills/ or $link_rel/) and re-run." >&2
      REFUSED=$((REFUSED + 1))
    else
      if [ "$DRY_RUN" = true ]; then
        echo "  Would move every entry from $link_rel/ into skills/, then replace $link_rel with a symlink"
        while IFS= read -r entry; do
          [ -z "$entry" ] && continue
          src="$link_path/$entry"
          if [ -L "$src" ]; then
            target_abs="$(cd "$src" 2>/dev/null && pwd -P || echo '')"
            if [[ "$target_abs" == "$CANONICAL/"* ]]; then
              echo "    Would drop redundant symlink $link_rel/$entry → $target_abs"
            else
              echo "    Would move $link_rel/$entry → skills/$entry (external symlink, preserved as symlink)"
            fi
          else
            tracked="no"
            [ "$GIT_REPO" = "yes" ] && tracked="$(git_tracked "$link_rel/$entry")"
            echo "    Would move $link_rel/$entry → skills/$entry (real, tracked=$tracked)"
          fi
        done < <(ls -A "$link_path" 2>/dev/null)
        CHANGES=$((CHANGES + 1))
      else
        mkdir -p "$CANONICAL"
        while IFS= read -r entry; do
          [ -z "$entry" ] && continue
          src="$link_path/$entry"
          dst="$CANONICAL/$entry"

          # Skip if already at destination (idempotent on partial states).
          d_real="$(real_path "$dst")"
          s_real="$(real_path "$src")"
          if [ -n "$d_real" ] && [ "$d_real" = "$s_real" ]; then
            continue
          fi

          if [ -L "$src" ]; then
            target_abs="$(cd "$src" 2>/dev/null && pwd -P || echo '')"
            if [[ "$target_abs" == "$CANONICAL/"* ]]; then
              # Redundant in-tree symlink — drop it; real content is/will be at canonical.
              tracked="no"
              [ "$GIT_REPO" = "yes" ] && tracked="$(git_tracked "$link_rel/$entry")"
              if [ "$tracked" = "yes" ]; then
                ( cd "$PROJECT_PATH" && git rm -q "$link_rel/$entry" )
              else
                rm -f "$src"
              fi
              echo "    dropped redundant symlink: $entry → $target_abs"
              continue
            fi
            # External symlink: move it intact.
            tracked="no"
            [ "$GIT_REPO" = "yes" ] && tracked="$(git_tracked "$link_rel/$entry")"
            if [ "$tracked" = "yes" ]; then
              ( cd "$PROJECT_PATH" && git mv "$link_rel/$entry" "skills/$entry" )
            else
              mv "$src" "$dst"
            fi
            echo "    moved (external symlink): $entry"
            continue
          fi

          # Real file or dir.
          tracked="no"
          [ "$GIT_REPO" = "yes" ] && tracked="$(git_tracked "$link_rel/$entry")"
          if [ "$tracked" = "yes" ]; then
            ( cd "$PROJECT_PATH" && git mv "$link_rel/$entry" "skills/$entry" )
          else
            mv "$src" "$dst"
          fi
          echo "    moved: $entry"
        done < <(ls -A "$link_path" 2>/dev/null)

        # Replace now-empty real dir with symlink.
        rmdir "$link_path" 2>/dev/null || rm -rf "$link_path"
        ( cd "$parent_path" && ln -s ../skills skills )
        [ "$GIT_REPO" = "yes" ] && ( cd "$PROJECT_PATH" && git add "$link_rel" )
        echo "  replaced $link_rel with symlink → ../skills"
        CHANGES=$((CHANGES + 1))
      fi
    fi
  else
    echo "  WARN: $link_rel exists but is neither dir nor symlink ($(file -b "$link_path" 2>/dev/null)) — leaving untouched"
  fi
  echo ""
}

ensure_runtime_skills_link ".claude" ".claude/skills" "Step 2a: <project>/.claude/skills"
ensure_runtime_skills_link ".agents" ".agents/skills" "Step 2b: <project>/.agents/skills"


# --- Step 3: AGENTS.md / CLAUDE.md ---

echo "Step 3: AGENTS.md / CLAUDE.md"
AGENTS_FILE="$PROJECT_PATH/AGENTS.md"
CLAUDE_FILE="$PROJECT_PATH/CLAUDE.md"

# Returns "yes" if CLAUDE.md exists AND looks like a one-line @AGENTS.md import.
# Heuristic: file size ≤ 64 bytes AND first non-empty trimmed line == "@AGENTS.md".
claude_is_import() {
  [ -f "$CLAUDE_FILE" ] || { echo "no"; return; }
  local size
  size="$(wc -c < "$CLAUDE_FILE" | tr -d ' ')"
  if [ "$size" -gt 64 ]; then
    echo "no"; return
  fi
  local first_line
  first_line="$(awk 'NF{print; exit}' "$CLAUDE_FILE" | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')"
  if [ "$first_line" = "@AGENTS.md" ]; then
    echo "yes"
  else
    echo "no"
  fi
}

write_claude_import() {
  if [ "$DRY_RUN" = true ]; then
    echo "  Would write CLAUDE.md = '@AGENTS.md'"
    return 0
  fi
  printf '@AGENTS.md\n' > "$CLAUDE_FILE"
  if [ "$GIT_REPO" = "yes" ]; then
    ( cd "$PROJECT_PATH" && git add CLAUDE.md )
  fi
  echo "  wrote CLAUDE.md = '@AGENTS.md'"
}

claude_exists=no
agents_exists=no
[ -f "$CLAUDE_FILE" ] && claude_exists=yes
[ -f "$AGENTS_FILE" ] && agents_exists=yes

if [ "$claude_exists" = "no" ] && [ "$agents_exists" = "no" ]; then
  echo "  OK — neither file present, nothing to do"
elif [ "$(claude_is_import)" = "yes" ] && [ "$agents_exists" = "yes" ]; then
  echo "  OK — already canonical (CLAUDE.md = @AGENTS.md, AGENTS.md present)"
elif [ "$claude_exists" = "no" ] && [ "$agents_exists" = "yes" ]; then
  write_claude_import
  CHANGES=$((CHANGES + 1))
elif [ "$claude_exists" = "yes" ] && [ "$agents_exists" = "no" ]; then
  # Move CLAUDE.md → AGENTS.md, then write CLAUDE.md = @AGENTS.md.
  if [ "$DRY_RUN" = true ]; then
    echo "  Would move CLAUDE.md → AGENTS.md, then write CLAUDE.md = '@AGENTS.md'"
  else
    tracked="no"
    [ "$GIT_REPO" = "yes" ] && tracked="$(git_tracked CLAUDE.md)"
    if [ "$tracked" = "yes" ]; then
      ( cd "$PROJECT_PATH" && git mv CLAUDE.md AGENTS.md )
    else
      mv "$CLAUDE_FILE" "$AGENTS_FILE"
    fi
    echo "  moved CLAUDE.md → AGENTS.md"
    write_claude_import
  fi
  CHANGES=$((CHANGES + 1))
else
  # Both exist with real content — compare.
  if cmp -s "$CLAUDE_FILE" "$AGENTS_FILE"; then
    # Byte-identical — overwrite CLAUDE.md to the import line.
    write_claude_import
    CHANGES=$((CHANGES + 1))
  else
    echo "  REFUSE: CLAUDE.md and AGENTS.md both exist with different content." >&2
    claude_lines="$(wc -l < "$CLAUDE_FILE" | tr -d ' ')"
    agents_lines="$(wc -l < "$AGENTS_FILE" | tr -d ' ')"
    echo "      CLAUDE.md: $claude_lines lines    AGENTS.md: $agents_lines lines" >&2
    echo "      diff (first 10 lines):" >&2
    diff -u "$CLAUDE_FILE" "$AGENTS_FILE" 2>/dev/null | head -10 | sed 's/^/        /' >&2 || true
    echo "    Merge into AGENTS.md by hand, delete CLAUDE.md (or shrink it to '@AGENTS.md'), then re-run." >&2
    REFUSED=$((REFUSED + 1))
  fi
fi
echo ""

# --- Summary ---

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$DRY_RUN" = true ]; then
  if [ "$CHANGES" -eq 0 ] && [ "$REFUSED" -eq 0 ]; then
    echo "already canonical (no changes needed)"
  else
    echo "dry run complete"
    [ "$CHANGES" -gt 0 ] && echo "  $CHANGES step(s) would change"
    [ "$REFUSED" -gt 0 ] && echo "  $REFUSED step(s) would refuse — see messages above"
  fi
else
  if [ "$CHANGES" -eq 0 ] && [ "$REFUSED" -eq 0 ]; then
    echo "already canonical"
  else
    echo "migration complete"
    [ "$CHANGES" -gt 0 ] && echo "  $CHANGES step(s) made changes"
    [ "$REFUSED" -gt 0 ] && echo "  $REFUSED step(s) refused — see messages above"
  fi
fi

[ "$REFUSED" -gt 0 ] && exit 3
exit 0
