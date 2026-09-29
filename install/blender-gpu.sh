#!/usr/bin/env bash
# Optional isolated HIP runtime; does not update the OS or /opt/rocm.
set -euo pipefail
command -v uv >/dev/null || { echo 'Install uv before running this script.' >&2; exit 1; }
runtime="$HOME/.local/share/gpu-lab/venv"
if [[ ! -x "$runtime/bin/python" ]]; then
  uv venv --python 3.12 "$runtime"
fi
uv pip install --python "$runtime/bin/python" \
  --index-url https://stable.repo.amd.com/rocm/whl-next/ 'rocm==10.0.0'
core="$runtime/lib/python3.12/site-packages/_rocm_sdk_core"
[[ -f "$core/lib/libamdhip64.so.7" ]] || { echo 'Unexpected ROCm package layout.' >&2; exit 1; }
# Blender's HIP-RT loader requests the unversioned library name. The core
# wheel ships only .so.7; keep the alias outside the package-owned directory.
mkdir -p "$HOME/.local/share/gpu-lab/compat"
ln -sfn "$core/lib/libamdhip64.so.7" "$HOME/.local/share/gpu-lab/compat/libamdhip64.so"
echo 'HIP runtime installed. Use the standalone Blender launcher to activate it.'
