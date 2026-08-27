#!/usr/bin/env bash
# Health check for the machine this repo is installed on.
#
# verify.sh is the Docker build's gate: it hardcodes /home/dev and only ever runs
# inside the image. Nothing checked the real machine, which is how a Homebrew tap
# deprecated in 2024 sat around until it broke `brew update` in 2026.
#
# This is read-only. It reports and never repairs -- the fix for each finding is
# printed next to it. Exit status is 1 if anything FAILed, 0 otherwise; warnings
# do not fail the run.
source "$(dirname "$0")/../lib/helpers.sh"

PASS=0 WARN=0 FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$*"; }
soft() { WARN=$((WARN + 1)); printf '  \033[33m!\033[0m %s\n' "$*"; }
hard() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$*"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

D="$DOTFILES_DIR"

# --- Config symlinks -------------------------------------------------------
# Every app here rewrites its own config in place at least sometimes, so a link
# can quietly become a real file and stop tracking the repo.
head_ "Config symlinks"

check_link() {
  local dest="$1" src="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    pass "${dest/#$HOME/\~}"
  elif [ -L "$dest" ]; then
    hard "${dest/#$HOME/\~} → $(readlink "$dest") (expected $src) — run: just link"
  elif [ -e "$dest" ]; then
    hard "${dest/#$HOME/\~} is a real file, not a link — an app overwrote it. Diff it, then: just link"
  else
    hard "${dest/#$HOME/\~} missing — run: just link"
  fi
}

if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  check_link "$HOME/.config/dotfiles/shell/omarchy.bash" "$D/config/shell/omarchy/dotfiles.bash"
  source_line='[[ -r "$HOME/.config/dotfiles/shell/omarchy.bash" ]] && source "$HOME/.config/dotfiles/shell/omarchy.bash"'
  if grep -Fqx -- "$source_line" "$HOME/.bashrc"; then
    pass "~/.bashrc sources the Omarchy dotfiles overlay"
  else
    hard "~/.bashrc does not source the Omarchy dotfiles overlay — run: just link"
  fi
  pass "Omarchy owns Git, tmux, Starship, Lazygit, Neovim, Herdr, terminal, and desktop configs"
else
  check_link "$HOME/.tmux.conf"               "$D/config/tmux/.tmux.conf"
  check_link "$HOME/.gitconfig"               "$D/config/git/.gitconfig"
  check_link "$HOME/.gitmessage"              "$D/config/git/.gitmessage"
  check_link "$HOME/.zshenv"                  "$D/config/zsh/.zshenv"
  check_link "$HOME/.zshrc"                   "$D/config/zsh/.zshrc"
  check_link "$HOME/.config/herdr/config.toml" "$D/config/herdr/config.toml"
  check_link "$HOME/.config/nvim"             "$D/config/nvim"
  check_link "$HOME/.config/starship.toml"    "$D/config/starship/macos.toml"
fi
if [ "$DOTFILES_PLATFORM" = macos ]; then
  check_link "$HOME/Library/Application Support/lazygit/config.yml" "$D/config/lazygit/config.yml"
  # Ghostty is linked on macOS only, matching where core.sh installs it.
  check_link "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "$D/config/terminal/macos/ghostty.conf"
elif [ "$DOTFILES_PLATFORM" != omarchy ]; then
  check_link "$HOME/.config/lazygit/config.yml" "$D/config/lazygit/config.yml"
fi

# --- Commands --------------------------------------------------------------
head_ "Commands"

check_cmd() {
  if has "$1"; then pass "$1"; else hard "$1 not found — run: just $2"; fi
}

for c in tmux nvim lazygit git direnv starship; do check_cmd "$c" core; done
if [ "$DOTFILES_PLATFORM" != omarchy ]; then check_cmd zsh core; fi
if [ "$DOTFILES_PLATFORM" = omarchy ] || [ "$DOTFILES_PLATFORM" = arch ]; then
  check_cmd mise runtimes
  for c in python uv node npm bun rustc cargo; do check_cmd "$c" runtimes; done
else
  for c in pyenv uv node npm bun rustc cargo; do check_cmd "$c" runtimes; done
fi
for c in gh jq yq just agent-browser portless;        do check_cmd "$c" tools;    done
# Mole is macOS-only, matching where tools.sh installs it.
if [ "$DOTFILES_PLATFORM" = macos ]; then check_cmd mole tools; fi
for c in herdr claude codex agy grok;                 do check_cmd "$c" agents;   done
if has pi || has pi-agent; then pass "pi"; else hard "pi not found — run: just agents"; fi

if [ "$DOTFILES_PLATFORM" = omarchy ]; then
  head_ "Omarchy applications"
  for c in 1password op chromium obsidian voxtype; do
    check_cmd "$c" omarchy-apps
  done
fi

# --- Global agent skills ---------------------------------------------------
# The only skills installed globally; everything else is per project. See
# docs/agent-skills-sources.md. ~/.agents/skills holds the canonical copy.
head_ "Global agent skills"

for s in herdr i-have-adhd agent-browser; do
  if [ -f "$HOME/.agents/skills/$s/SKILL.md" ]; then
    pass "$s"
  else
    hard "$s missing from ~/.agents/skills — run: just agents"
  fi
done

# agent-browser's installed file is only a discovery stub; its real content is
# served by the CLI. Stub without CLI is a live pointer to a missing command.
if [ -f "$HOME/.agents/skills/agent-browser/SKILL.md" ] && ! has agent-browser; then
  hard "agent-browser skill installed but its CLI is missing — the stub points at a command that does not exist. Run: just tools"
fi

# --- Agent config drift ----------------------------------------------------
head_ "Agent configs"

if bash "$D/tools/agent-links.sh" check >/dev/null 2>&1; then
  pass "no agent config links back into this repo"
else
  soft "some agent config still links into this repo — see: just check-agent-links"
fi

# --- Homebrew --------------------------------------------------------------
# A tap whose remote is gone makes `brew update` fail outright, which silently
# staleness-freezes every brew install the repo does.
if [ "$DOTFILES_PLATFORM" = macos ] && has brew; then
  head_ "Homebrew taps"
  for t in $(brew tap 2>/dev/null); do
    repo="$(brew --repo "$t" 2>/dev/null)"
    if [ ! -d "$repo/.git" ]; then
      soft "$t has no git repo — run: brew untap $t"
    elif git -C "$repo" ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
      pass "$t"
    else
      hard "$t remote is unreachable — this breaks \`brew update\`. Run: brew untap $t"
    fi
  done
fi

# --- macOS protected folders -----------------------------------------------
# ~/Documents and ~/Desktop are TCC-protected, and one terminal process tree can
# lose access to them while every other tree on the machine keeps working
# (anthropics/claude-code#58952, open, no root cause). It shows up as `claude`
# exiting with EPERM and every subshell printing "getcwd: cannot access parent
# directories", which reads like a permissions or install problem and is neither
# -- nothing on disk changed, and the TCC database records no denial.
#
# Deliberately scoped to whichever tree runs doctor, because that is the only
# thing worth measuring: run it from the terminal that is misbehaving. Warned
# rather than failed, since this is a transient runtime state and not a defect
# in how this repo is installed.
if [ "$DOTFILES_PLATFORM" = macos ]; then
  head_ "Protected folders (this process tree only)"
  for dir in "$HOME/Documents" "$HOME/Desktop"; do
    [ -d "$dir" ] || continue
    if ls "$dir" >/dev/null 2>&1; then
      pass "${dir/#$HOME/\~} readable"
    else
      soft "${dir/#$HOME/\~} unreadable from this tree — rebuild it: herdr server stop (HERDR_SOCKET_PATH=~/.config/herdr/herdr.sock), then quit the terminal with ⌘Q and relaunch"
    fi
  done
fi

# --- Summary ---------------------------------------------------------------
printf '\n\033[1mSummary:\033[0m %d passed, %d warning(s), %d failed\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ] || { printf '\033[31mSome checks failed.\033[0m\n' >&2; exit 1; }
printf '\033[32mAll good.\033[0m\n'
