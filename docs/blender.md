# Standalone Blender on Linux

Install the official Linux x86_64 build without a system package upgrade:

```sh
bash ~/.dotfiles/install/blender-standalone.sh 5.2.2
bash ~/.dotfiles/install/blender-gpu.sh  # optional isolated AMD HIP runtime
```

The Blender archive is checked against the official SHA-256 manifest. Releases
live in `~/.local/opt/blender/`, with `current` selecting the active release.
`~/.local/bin/blender` links to this repository's `config/blender/launch.sh`.
An application launcher entry is installed. Preferences remain host-owned in
`~/.config/blender/`. These optional scripts are not part of `just setup`.

The GPU script requires `uv` and installs AMD's official `rocm==10.0.0` Python
package into `~/.local/share/gpu-lab/venv` (Python 3.12). It does not replace
`/opt/rocm`, the Linux kernel, Mesa, or system packages. This is the core runtime,
not a PyTorch/ML environment or a complete developer installation. AMD's host
and per-device math libraries must be added separately for such workloads.

For this optional environment, the Blender wrapper scopes two compatibility
adjustments to the Blender process:

- ROCm libraries on `LD_LIBRARY_PATH`, including an unversioned
  `libamdhip64.so` alias outside the wheel directory for Blender's HIP-RT loader.
- `CQ_THREAD_STACK_SIZE=8388608`: the original queue-thread stack produced
  `pthread_create(EINVAL)` with Blender 5.2.2/ROCm 10 on this host; 8 MiB passed
  repeated renders. This is a tested host workaround, not a general guarantee
  for every driver or future version. No preload shim is used by the launcher.

In Blender, choose **Edit → Preferences → System → Cycles Render Devices → HIP**
and select the AMD GPU. For a Cycles scene, also choose **Render Properties →
Device → GPU Compute**. EEVEE uses the graphics driver independently of HIP.
The GPU is not necessarily faster than CPU; compare your actual scene.

Validated on 2026-09-29 with Ryzen AI 9 HX 470 / Radeon 890M (`gfx1150`),
Omarchy kernel 7.2.5-4, Mesa 26.2.3, and official Blender 5.2.2. Hardware ray
tracing was confirmed by the Cycles debug log, not just the preferences checkbox.

Remove the desktop entry and `~/.local/bin/blender` link to disable integration.
The standalone releases and optional `gpu-lab` environment can be removed
independently; retain Blender preferences and project files as needed.

Sources: [Blender releases](https://download.blender.org/release/Blender5.2/),
[AMD installation guide](https://rocmdocs.amd.com/en/develop/install/rocm.html),
[AMD TheRock packages](https://github.com/ROCm/TheRock/blob/main/RELEASES.md).
