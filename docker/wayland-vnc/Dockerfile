# A Wayland desktop in a container, reachable over VNC.
#
# This is sway, not Hyprland, and that is not a preference. Hyprland cannot start
# in a container at all: Aquamarine (its backend since it dropped wlroots) builds
# its allocator from the DRM backend, so even the headless fallback dies with
# "Cannot open backend: no allocator available". A render node is not enough --
# it needs a KMS-capable card, and no container host on Apple Silicon provides
# one. wlroots' headless backend needs no DRM device whatsoever, so sway works.
#
# amd64 on purpose: this is meant to approximate an Arch/Omarchy environment, and
# Arch is x86_64. Under Colima started with --vz-rosetta that is Rosetta-translated;
# check for /usr/bin/qemu-x86_64-static inside the container to tell whether you
# landed on the much slower QEMU user-mode path instead.
FROM --platform=linux/amd64 archlinux:latest

# pacman 7 sandboxes downloads with seccomp, and installing a seccomp filter
# returns EINVAL under translation, so every pacman call would die with
# "switching to sandbox user 'alpm' failed". The container is already the
# isolation boundary here.
RUN echo 'DisableSandbox' >> /etc/pacman.conf

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
      sway swaybg wayvnc foot \
      mesa libglvnd \
      noto-fonts noto-fonts-cjk ttf-jetbrains-mono-nerd \
      procps-ng which \
  && pacman -Scc --noconfirm \
  && rm -rf /var/cache/pacman/pkg/*

# sway ships with cap_sys_nice=ep. Executing a file with capabilities fails with
# EPERM when the container's bounding set lacks them, which reads as the confusing
# "Operation not permitted" on exec. Stripping it beats requiring --cap-add.
RUN setcap -r /usr/sbin/sway

COPY sway-config /etc/sway/config
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# Everything here renders on the CPU via llvmpipe; there is no GPU to reach.
ENV XDG_RUNTIME_DIR=/run/user/0 \
    WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    LIBGL_ALWAYS_SOFTWARE=1

EXPOSE 5900
CMD ["/usr/local/bin/start.sh"]
