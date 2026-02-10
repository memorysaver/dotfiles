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
  (.agent.name // "")
')

DIR="${_F[0]}"
MODEL="${_F[1]}"
PCT="${_F[2]}"
COST="${_F[3]}"
VIM="${_F[4]}"
AGENT="${_F[5]}"

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

# user: folder/worktree/branch | Model | ctx% | $cost | HH:MM:SS [VIM] (agent)
printf '%b' "\033[32m${_USER}\033[0m: ${PATH_FMT} | ${MODEL} | \033[${CTX_COLOR}m${PCT}%\033[0m${COST_FMT} | $(date '+%H:%M:%S')${VIM_FMT}${AGENT_FMT}"
