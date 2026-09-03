#!/usr/bin/env bash
# Clone or update personal repositories under the shared ~/Work layout.
source "$(dirname "$0")/../lib/helpers.sh"

REPOS_FILE="$(dirname "$0")/repos.txt"
WORKSPACE_GITHUB="$HOME/Work/github"
LEGACY_GITHUB="$HOME/Documents/github"
LEGACY_CHECKABLE=true

info "Syncing personal workspace repos..."
ensure_dir "$WORKSPACE_GITHUB"
if [ -d "$HOME/Documents" ] && ! ls "$HOME/Documents" >/dev/null 2>&1; then
  LEGACY_CHECKABLE=false
  warn "Cannot inspect $HOME/Documents from this process"
  warn "Missing destinations will be skipped to avoid duplicating an unseen legacy repository"
fi

while IFS= read -r line; do
  # Skip blank lines and comments
  [[ -z "$line" || "$line" == \#* ]] && continue

  url="$line"
  name=$(basename "$url" .git)
  dest="$WORKSPACE_GITHUB/$name"
  legacy_dest="$LEGACY_GITHUB/$name"

  if [ ! -e "$dest" ]; then
    if [ "$LEGACY_CHECKABLE" = false ]; then
      warn "Cannot safely determine whether $legacy_dest exists — skipping $name"
      continue
    elif [ -e "$legacy_dest" ] || [ -L "$legacy_dest" ]; then
      warn "$legacy_dest already exists while $dest does not — skipping"
      warn "Inspect the legacy repository and migrate it explicitly; this command never moves projects"
      continue
    fi
    info "Cloning $name → $dest"
    git clone "$url" "$dest" && ok "$name cloned"
  elif [ -d "$dest/.git" ]; then
    info "Pulling $name..."
    git -C "$dest" pull && ok "$name up to date"
  else
    warn "$dest exists but is not a git repo — skipping"
  fi
done < "$REPOS_FILE"

ok "Workspace repos done"
