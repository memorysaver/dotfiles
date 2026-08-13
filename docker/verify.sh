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
check_symlink "$HOME/.config/herdr/config.toml"            "$D/config/herdr/config.toml"
# Agent configs are NOT symlinked -- `just seed-agents` copies them once and each
# machine owns its copy from then on. Skills install per project. Both are checked
# below as real files, not links.

echo ""
echo "=== Agent configs (real files, seeded not linked) ==="
check_real_file() {
  local p="$1"
  if [ -L "$p" ]; then
    fail "should be a real file, not a symlink: $p"
  elif [ -e "$p" ]; then
    ok "$p"
  else
    fail "missing: $p"
  fi
}
check_real_file "$HOME/.claude/settings.json"
check_real_file "$HOME/.claude/statusline.sh"
check_real_file "$HOME/.claude/hooks/cmux-notify.sh"
check_real_file "$HOME/.codex/config.toml"
check_real_file "$HOME/.codex/AGENTS.md"
check_real_file "$HOME/.pi/agent/settings.json"
check_real_file "$HOME/.config/opencode/opencode.json"
check_real_file "$HOME/.config/opencode/oh-my-opencode.json"

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
check_cmd herdr; check_cmd claude; check_cmd codex; check_cmd agy; check_cmd grok

if command -v pi >/dev/null 2>&1; then
  ok "command: pi"
elif command -v pi-agent >/dev/null 2>&1; then
  ok "command: pi-agent"
else
  fail "command not found: pi or pi-agent"
fi

echo ""
echo "=== Shared Skills ==="
bash "$D/tools/validate-agent-skills.sh" || fail "shared skill validation"

# The only skills installed globally -- see docs/agent-skills-sources.md.
# ~/.agents/skills holds the canonical copy; per-agent global dirs symlink to it.
check_real_file "$HOME/.agents/skills/herdr/SKILL.md"
check_real_file "$HOME/.agents/skills/i-have-adhd/SKILL.md"
check_real_file "$HOME/.agents/skills/agent-browser/SKILL.md"

echo ""
echo "=== Summary: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || { echo "VERIFICATION FAILED" >&2; exit 1; }
echo "All checks passed."
