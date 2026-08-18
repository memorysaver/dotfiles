#!/bin/bash
# Bring up sway headless, then point wayvnc at whatever wayland socket it created.
set -u

export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/0}
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

echo "[start] launching sway (headless, ${WLR_RENDERER:-default} renderer)"
sway -c /etc/sway/config &
SWAY_PID=$!

# Wait for the socket rather than sleeping a fixed amount. The display number is
# not stable -- it came up as wayland-1 during testing, so guessing wayland-0
# gives "Failed to connect to WAYLAND_DISPLAY" and an empty VNC port.
WL=""
for _ in $(seq 1 60); do
  WL=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'wayland-[0-9]*' ! -name '*.lock' \
       -printf '%f\n' 2>/dev/null | head -1)
  [ -n "$WL" ] && break
  sleep 1
done

if [ -z "$WL" ]; then
  echo "[start] FATAL: sway never created a wayland socket" >&2
  kill "$SWAY_PID" 2>/dev/null
  exit 1
fi

echo "[start] sway is up on $WL; serving VNC on 0.0.0.0:5900"
export WAYLAND_DISPLAY="$WL"
exec wayvnc -L info 0.0.0.0 5900
