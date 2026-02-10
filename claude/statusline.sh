#!/bin/bash
input=$(cat)

# Static values (cached in-process)
_USER="${_SL_USER:=$(whoami)}"

# Extract JSON fields — one per line, read with a loop (bash 3.2 compatible)
_idx=0
while IFS= read -r _line; do
  _F[_idx]="$_line"
  ((_idx++))
done < <(echo "$input" | jq -r '
  .workspace.current_dir // "",
  .model.display_name // "",
  (.context_window.used_percentage // 0 | round),
  (.cost.total_cost_usd // 0 | . * 100 | round | . / 100),
  (.vim.mode // ""),
  (.agent.name // ""),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.cost.total_duration_ms // 0),
  (.context_window.context_window_size // 200000),
  (.version // "")
')

DIR="${_F[0]}"
MODEL="${_F[1]}"
PCT="${_F[2]}"
COST="${_F[3]}"
VIM="${_F[4]}"
AGENT="${_F[5]}"
LINES_ADD="${_F[6]}"
LINES_DEL="${_F[7]}"
DURATION_MS="${_F[8]}"
CTX_SIZE="${_F[9]}"
VERSION="${_F[10]}"

# Git info with 5s cache (branch + worktree name)
_GIT_CACHE="/tmp/statusline-git-cache"
_GIT_TTL=5
_git_info() {
  local now
  now=$(date +%s)
  if [[ -f "$_GIT_CACHE" ]]; then
    local cached_time cached_data
    IFS= read -r cached_data < "$_GIT_CACHE"
    cached_time="${cached_data%%	*}"
    cached_data="${cached_data#*	}"
    if (( now - cached_time < _GIT_TTL )); then
      echo "$cached_data"
      return
    fi
  fi
  local branch="" worktree=""
  if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    # Detect worktree: if .git is a file (not dir), we're in a linked worktree
    local git_dir
    git_dir=$(git rev-parse --git-dir 2>/dev/null)
    if [[ "$git_dir" == */.git/worktrees/* ]]; then
      worktree="${git_dir##*/worktrees/}"
    fi
  fi
  printf '%s\t%s\t%s' "$now" "$branch" "$worktree" > "$_GIT_CACHE"
  printf '%s\t%s' "$branch" "$worktree"
}

IFS=$'\t' read -r BRANCH WORKTREE < <(_git_info)

# Context color: green <70%, yellow 70-89%, red 90%+
if (( PCT >= 90 )); then
  CTX_COLOR="31"
elif (( PCT >= 70 )); then
  CTX_COLOR="33"
else
  CTX_COLOR="32"
fi

# Format cost (hide when zero)
COST_FMT=""
[[ "$COST" != "0" ]] && COST_FMT=" | \$${COST}"

# Build path: folder/branch(worktree) or folder/branch(no worktree)
BRANCH_FMT=""
if [[ -n "$BRANCH" ]]; then
  if [[ -n "$WORKTREE" ]]; then
    BRANCH_FMT="\033[35m${BRANCH}\033[0m(\033[33m${WORKTREE}\033[0m)"
  else
    BRANCH_FMT="\033[35m${BRANCH}\033[0m(\033[2mno worktree\033[0m)"
  fi
fi
PATH_FMT="\033[34m${DIR##*/}\033[0m"
[[ -n "$BRANCH_FMT" ]] && PATH_FMT="${PATH_FMT}/${BRANCH_FMT}"

VIM_FMT=""
[[ "$VIM" == "NORMAL" || "$VIM" == "INSERT" ]] && VIM_FMT=" [\033[36m${VIM}\033[0m]"

AGENT_FMT=""
[[ -n "$AGENT" && "$AGENT" != "null" ]] && AGENT_FMT=" \033[33m(${AGENT})\033[0m"

# Format context size: 200000 → 200K, 1000000 → 1M
CTX_SIZE_FMT=""
if [[ -n "$CTX_SIZE" && "$CTX_SIZE" != "0" ]]; then
  if (( CTX_SIZE >= 1000000 )); then
    CTX_SIZE_FMT=" of $((CTX_SIZE / 1000000))M"
  else
    CTX_SIZE_FMT=" of $((CTX_SIZE / 1000))K"
  fi
fi

# Format lines added/removed (git diff style), hide if both zero
LINES_FMT=""
if (( LINES_ADD > 0 || LINES_DEL > 0 )); then
  LINES_FMT=" \033[32m+${LINES_ADD}\033[0m \033[31m-${LINES_DEL}\033[0m"
fi

# Format duration: ms → Xs, Xm Ys, or Xh Ym
DUR_FMT=""
if (( DURATION_MS > 0 )); then
  _total_s=$((DURATION_MS / 1000))
  if (( _total_s >= 3600 )); then
    DUR_FMT=" | $((_total_s / 3600))h $((_total_s % 3600 / 60))m"
  elif (( _total_s >= 60 )); then
    DUR_FMT=" | $((_total_s / 60))m $((_total_s % 60))s"
  else
    DUR_FMT=" | ${_total_s}s"
  fi
fi

# Format version (dimmed)
VER_FMT=""
[[ -n "$VERSION" && "$VERSION" != "null" ]] && VER_FMT=" | \033[2mv${VERSION#v}\033[0m"

# user: folder/branch(worktree) +N -N | Model | ctx% of size | $cost | duration | HH:MM:SS [VIM] (agent) | version
printf '%b' "\033[32m${_USER}\033[0m: ${PATH_FMT}${LINES_FMT} | ${MODEL} | \033[${CTX_COLOR}m${PCT}%${CTX_SIZE_FMT}\033[0m${COST_FMT}${DUR_FMT} | $(date '+%H:%M:%S')${VIM_FMT}${AGENT_FMT}${VER_FMT}"
