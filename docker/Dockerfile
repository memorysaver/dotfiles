# syntax=docker/dockerfile:1
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV DOTFILES_OS=linux
ENV NVM_DIR=/home/dev/.nvm
ENV PATH="/home/dev/.pyenv/bin:/home/dev/.bun/bin:/home/dev/.cargo/bin:/home/dev/.local/bin:${PATH}"
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# 1. Minimal prerequisites
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      sudo curl wget git build-essential unzip \
      ca-certificates gnupg lsb-release zsh locales && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Non-root user with passwordless sudo
RUN useradd -m -s /bin/bash dev && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/dev && \
    chmod 0440 /etc/sudoers.d/dev

# 3. Install `just` system-wide (needed to run `just setup`)
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh \
      | bash -s -- --to /usr/local/bin

# 4. Copy dotfiles repo into dev's home
COPY --chown=dev:dev . /home/dev/.dotfiles

USER dev
WORKDIR /home/dev

# 5. Run setup in phases — source nvm between runtimes and agents
#    so npm/node is on PATH when agents.sh runs (just spawns fresh subshells)
RUN bash <<'SCRIPT'
set -euo pipefail
sudo apt-get update -y
cd /home/dev/.dotfiles
just core
just runtimes
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
just agents
just tools
just link
SCRIPT

# 6. Verify all symlinks and installed commands
RUN bash /home/dev/.dotfiles/docker/verify.sh

CMD ["/bin/zsh"]
