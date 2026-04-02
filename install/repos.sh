#!/usr/bin/env bash
# Clone or update personal workspace repos listed in install/repos.txt
source "$(dirname "$0")/../lib/helpers.sh"

REPOS_FILE="$(dirname "$0")/repos.txt"

info "Syncing personal workspace repos..."

while IFS= read -r line; do
  # Skip blank lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  url="$line"
  name=$(basename "$url" .git)
  dest="$HOME/$name"

  if [ ! -e "$dest" ]; then
    info "Cloning $name → ~/$name"
    git clone "$url" "$dest" && ok "$name cloned"
  elif [ -d "$dest/.git" ]; then
    info "Pulling $name..."
    git -C "$dest" pull && ok "$name up to date"
  else
    warn "$dest exists but is not a git repo — skipping"
  fi
done < "$REPOS_FILE"

ok "Workspace repos done"
