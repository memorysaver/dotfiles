#!/usr/bin/env bash
# Keep optional HIP runtime settings local to Blender, not the desktop session.
set -euo pipefail
runtime="$HOME/.local/share/gpu-lab/venv/lib/python3.12/site-packages/_rocm_sdk_core/lib"
if [[ -f "$runtime/libamdhip64.so.7" ]]; then
  compat="$HOME/.local/share/gpu-lab/compat"
  export LD_LIBRARY_PATH="$runtime:$compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  # ROCm 10's small queue-thread stack fails pthread_create(EINVAL) in the
  # official Blender 5.2.2 build on this Arch/glibc environment. 8 MiB passes
  # repeated Cycles HIP renders; no global stack or driver setting is changed.
  export CQ_THREAD_STACK_SIZE=${CQ_THREAD_STACK_SIZE:-8388608}
fi
exec "$HOME/.local/opt/blender/current/blender" "$@"
