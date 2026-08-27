#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_home="$(mktemp -d /tmp/dotfiles-terminal-test.XXXXXX)"
trap 'rm -rf "$test_home"' EXIT

for file in \
  "$repo_root/config/shell/common/env.sh" \
  "$repo_root/config/shell/common/aliases.sh" \
  "$repo_root/config/shell/common/functions.sh" \
  "$repo_root/config/shell/omarchy/dotfiles.bash"; do
  bash -n "$file"
done

ln -s "$repo_root" "$test_home/.dotfiles"
HOME="$test_home" bash --noprofile --norc -c '
  source "$HOME/.dotfiles/config/shell/omarchy/dotfiles.bash"
  type chrome-cdp >/dev/null
  type ab-connect >/dev/null
  alias ccyolo >/dev/null
'

HOME="$test_home" DOTFILES_PLATFORM=omarchy bash --noprofile --norc -c '
  source "$HOME/.dotfiles/lib/helpers.sh"
  config="$HOME/bashrc"
  line="source dotfiles-overlay"
  printf "base\n" >"$config"
  ensure_source_line "$config" "$line" >/dev/null
  ensure_source_line "$config" "$line" >/dev/null
  [ "$(grep -Fxc "$line" "$config")" -eq 1 ]
  remove_source_line "$config" "$line" >/dev/null
  ! grep -Fqx "$line" "$config"
'

HOME="$test_home" XDG_CACHE_HOME="$test_home/.cache" \
  TERM=xterm-256color STARSHIP_CONFIG="$repo_root/config/starship/macos.toml" \
  starship prompt >/dev/null

rg -F 'warn "Omarchy: preserving Git, tmux, Starship, Lazygit, Neovim, Herdr, and terminal configs"' \
  "$repo_root/justfile" >/dev/null

if rg -n 'config/starship/omarchy|starship_profile=omarchy' \
  "$repo_root/justfile" "$repo_root/README.md" "$repo_root/tools" >/dev/null; then
  echo "Omarchy Starship config must remain host-owned" >&2
  exit 1
fi

echo "terminal config smoke test passed"
