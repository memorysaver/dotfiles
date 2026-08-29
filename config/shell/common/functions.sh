# Browser automation helpers supported by both Bash and Zsh.
_chrome_cdp_ready() {
  local port="${1:-9222}"
  curl -fsS "http://127.0.0.1:${port}/json/version" >/dev/null 2>&1
}

_chrome_cdp_clear_stale_locks() {
  local dir="$1"
  local lock="$dir/SingletonLock"
  local target pid

  [ -e "$lock" ] || return 0
  target="$(readlink "$lock" 2>/dev/null || true)"
  pid="${target##*-}"

  case "$pid" in
    ''|*[!0-9]*) ;;
    *)
      if kill -0 "$pid" 2>/dev/null; then
        echo "Chrome profile is already locked by PID $pid: $dir" >&2
        return 1
      fi
      ;;
  esac

  rm -f "$dir/SingletonLock" "$dir/SingletonSocket" "$dir/SingletonCookie"
}

chrome-cdp() {
  local name="${1:-default}"
  local port="${2:-9222}"
  local dir="$HOME/.chrome-cdp/$name"
  local browser i

  mkdir -p "$dir"

  if _chrome_cdp_ready "$port"; then
    echo "Chrome '$name' already listening on port $port"
    return 0
  fi

  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $port is in use, but it is not a reachable Chrome CDP endpoint" >&2
    return 1
  fi

  _chrome_cdp_clear_stale_locks "$dir" || return 1

  if [ "$(uname -s)" = Darwin ]; then
    open -na "Google Chrome" --args \
      --remote-debugging-port="$port" \
      --remote-allow-origins="*" \
      --user-data-dir="$dir"
  else
    browser="$(command -v chromium || command -v google-chrome || true)"
    [ -n "$browser" ] || { echo "Chromium/Chrome not found" >&2; return 1; }
    setsid "$browser" \
      --remote-debugging-port="$port" \
      --remote-allow-origins="*" \
      --user-data-dir="$dir" >/dev/null 2>&1 &
  fi

  i=1
  while [ "$i" -le 20 ]; do
    if _chrome_cdp_ready "$port"; then
      echo "Chrome '$name' on port $port"
      return 0
    fi
    sleep 0.25
    i=$((i + 1))
  done

  echo "Chrome '$name' was launched, but CDP did not become reachable on port $port" >&2
  return 1
}

ab-connect() {
  local name="${1:-default}"
  local port="${2:-9222}"

  chrome-cdp "$name" "$port" || return 1
  env -u AGENT_BROWSER_PROFILE agent-browser --session "$name" connect "$port"
}

# Use an existing Chromium profile when a task explicitly needs the human's
# logged-in browser state. Keep this opt-in: profile-backed sessions cannot use
# agent-browser's --allowed-domains containment and expose the profile's cookies.
ab-profile() {
  local profile="${1:-mfa}"
  local url="${2:-about:blank}"
  local session="profile-${profile//[^[:alnum:]_-]/-}"

  agent-browser --session "$session" --profile "$profile" open "$url"
}

# Start with a clean browser when a task must not inherit personal cookies.
ab-isolated() {
  local name="${1:-isolated}"
  local url="${2:-about:blank}"

  env -u AGENT_BROWSER_PROFILE agent-browser --session "$name" open "$url"
}
