# wayland-vnc

A throwaway Arch container running a Wayland desktop you can reach with a VNC
client from the Mac. Built while evaluating whether [Omarchy](https://omarchy.org/)
could be tried without giving up a disk to it.

Unrelated to `docker/Dockerfile`, which is the Ubuntu image that verifies this
repo installs cleanly.

## Run it

Needs a Colima profile with Rosetta, because the image is amd64:

```sh
colima start -p omarchy --vm-type vz --vz-rosetta --cpu 4 --memory 8 --disk 60
docker --context colima-omarchy build --platform linux/amd64 -t wayland-vnc docker/wayland-vnc
docker --context colima-omarchy run -d --name wv --platform linux/amd64 -p 5900:5900 wayland-vnc
```

Then point any VNC client at `localhost:5900` — no password, so do not publish
the port anywhere but loopback. macOS Screen Sharing works: `⌘K`, `vnc://localhost:5900`.

Mod is Super. `Mod+Return` opens a terminal, `Mod+q` closes a window, `Mod+e` exits.

## Why this is sway and not Hyprland

Hyprland cannot start in a container at all, and this is not a performance
question. Aquamarine, its backend since it dropped wlroots, builds its buffer
allocator from the DRM backend, so even the headless fallback ends at:

```
DRM Backend failed
Cannot open backend: no allocator available
```

Handing it a render node is not enough. It wants a KMS-capable card, and nothing
available on Apple Silicon provides one — Colima's kernel has neither a virtio-gpu
device nor the `vkms` module, and podman's libkrun provider does expose
`/dev/dri/card0` but reports `[drm] KMS disabled`, so `libseat` cannot open it even
as root in a rootful machine. wlroots' headless backend needs no DRM device at all,
which is the whole reason sway works here.

Everything renders through llvmpipe on the CPU. Window management, terminals and
editors are fine; anything that animates is not.

## Gotchas worth keeping

- **Port 5900 collides.** Colima and Lima publish ports with an ssh forward that
  binds IPv4, and other forwarders may only get IPv6 — connections to
  `127.0.0.1:5900` then land on the wrong process and hang without a banner.
  `lsof -nP -iTCP:5900 -sTCP:LISTEN` shows who actually holds it.
- **Testing with `nc` lies here.** This image has no `nc`, so a test that pipes
  through it returns empty and looks like a broken server. Use bash instead:
  `exec 3<>/dev/tcp/127.0.0.1/5900 && head -c 12 <&3` should print `RFB 003.008`.
- The wayland socket number is not stable — it came up as `wayland-1`, so
  `start.sh` discovers it rather than assuming `wayland-0`.
