#!/usr/bin/env bash
# Make `pi` runnable on grok-bot.
#
# Pi (@earendil-works/pi-coding-agent) needs Node >= 22.19, but the Grok Bot
# Debian sandbox ships Node 20, where the npm bin link dies on startup
# (`node:fs` has no `globSync`). Bun runs Pi's bundled cli.js fine, so on an old
# Node we replace npm's ~/.local/bin/pi symlink with a small wrapper that execs
# the same cli.js through Bun. On Node >= 22.19 the npm link is left alone.
#
# Usage:
#   grok-bot-pi-shim.sh           write the wrapper if needed (idempotent)
#   grok-bot-pi-shim.sh --remove  delete our wrapper so `npm install -g` can relink
source "$(dirname "$0")/../lib/helpers.sh"

[ "$DOTFILES_PLATFORM" = grok-bot ] || exit 0

PI_NPM_PACKAGE="${PI_NPM_PACKAGE:-@earendil-works/pi-coding-agent}"
marker="dotfiles:grok-bot-pi-shim"
bin_dir="$HOME/.local/bin"
wrapper="$bin_dir/pi"

if [ "${1:-}" = "--remove" ]; then
  if [ -f "$wrapper" ] && [ ! -L "$wrapper" ] && grep -Fq "$marker" "$wrapper"; then
    rm -f "$wrapper"
  fi
  exit 0
fi

has npm || { warn "npm not found — skipping Pi shim"; exit 0; }
cli="$(npm root -g 2>/dev/null)/$PI_NPM_PACKAGE/dist/bundle/cli.js"
if [ ! -f "$cli" ]; then
  warn "Pi not installed via npm ($cli missing) — skipping Pi shim"
  exit 0
fi

node_ok() {
  has node || return 1
  local v major minor
  v="$(node --version 2>/dev/null)"; v="${v#v}"
  major="${v%%.*}"; minor="${v#*.}"; minor="${minor%%.*}"
  [ "$major" -gt 22 ] || { [ "$major" -eq 22 ] && [ "$minor" -ge 19 ]; }
}

if node_ok; then
  ok "Node $(node --version) runs Pi directly — no shim needed"
  exit 0
fi

if ! has bun && [ -x "$HOME/.bun/bin/bun" ]; then
  export PATH="$HOME/.bun/bin:$PATH"
fi
has bun || { warn "Node $(node --version 2>/dev/null) is too old for Pi and bun is missing — pi will not start"; exit 0; }

ensure_dir "$bin_dir"
tmp="$(mktemp)"
cat >"$tmp" <<WRAP
#!/usr/bin/env bash
# $marker — managed by dotfiles install/grok-bot-pi-shim.sh
# Pi needs Node >= 22.19; this box's Node is older, so run Pi's cli.js with Bun.
exec bun "$cli" "\$@"
WRAP
if [ -f "$wrapper" ] && [ ! -L "$wrapper" ] && cmp -s "$tmp" "$wrapper"; then
  rm -f "$tmp"
  ok "Pi Bun wrapper already in place ($wrapper)"
else
  rm -f "$wrapper"
  mv "$tmp" "$wrapper"
  chmod +x "$wrapper"
  ok "Pi Bun wrapper written ($wrapper → bun $cli)"
fi
