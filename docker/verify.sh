#!/usr/bin/env bash
set -euo pipefail

PASS=0; FAIL=0

ok()   { echo "  [PASS] $*"; ((PASS++)) || true; }
fail() { echo "  [FAIL] $*" >&2; ((FAIL++)) || true; }

check_symlink() {
  local dest="$1" src="$2"
  if [ ! -L "$dest" ]; then
    fail "Not a symlink: $dest"
  elif [ "$(readlink "$dest")" != "$src" ]; then
    fail "Wrong target: $dest → $(readlink "$dest") (expected $src)"
  else
    ok "$dest → $src"
  fi
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    ok "command: $cmd"
  else
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" 2>/dev/null || true
    command -v "$cmd" &>/dev/null && ok "command (nvm): $cmd" || fail "command not found: $cmd"
  fi
}

D=/home/dev/.dotfiles

echo "=== Symlinks ==="
check_symlink "$HOME/.zshrc"                               "$D/config/zsh/.zshrc"
check_symlink "$HOME/.tmux.conf"                           "$D/config/tmux/.tmux.conf"
check_symlink "$HOME/.gitconfig"                           "$D/config/git/.gitconfig"
check_symlink "$HOME/.gitmessage"                          "$D/config/git/.gitmessage"
check_symlink "$HOME/.config/nvim"                         "$D/config/nvim"
check_symlink "$HOME/.config/starship.toml"                "$D/config/starship/starship.toml"
check_symlink "$HOME/.config/lazygit/config.yml"           "$D/config/lazygit/config.yml"
check_symlink "$HOME/.claude/settings.json"                "$D/agents/claude/settings.json"
check_symlink "$HOME/.claude/mcp-servers.json"             "$D/agents/claude/mcp-servers.json"
check_symlink "$HOME/.claude/statusline.sh"                "$D/agents/claude/statusline.sh"
check_symlink "$HOME/.claude/hooks/cmux-notify.sh"         "$D/agents/claude/hooks/cmux-notify.sh"
check_symlink "$HOME/.codex/config.toml"                   "$D/agents/codex/config.toml"
check_symlink "$HOME/.config/opencode/opencode.json"       "$D/agents/opencode/opencode.json"
check_symlink "$HOME/.config/opencode/oh-my-opencode.json" "$D/agents/opencode/oh-my-opencode.json"
check_symlink "$HOME/.envrc"                               "$D/env/.envrc"

echo ""
echo "=== Commands ==="
# Core
check_cmd zsh; check_cmd tmux; check_cmd nvim; check_cmd lazygit
check_cmd git; check_cmd direnv; check_cmd starship
# Runtimes
check_cmd pyenv; check_cmd uv; check_cmd node; check_cmd npm
check_cmd bun; check_cmd rustc; check_cmd cargo
# Tools
check_cmd gh; check_cmd jq; check_cmd yq; check_cmd just
# Agents
check_cmd claude; check_cmd codex

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || { echo "VERIFICATION FAILED" >&2; exit 1; }
echo "All checks passed."
