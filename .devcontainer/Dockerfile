FROM node:20-bookworm

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    openssh-client \
    openssh-server \
    python3 \
    python3-pip \
    python3-venv \
    unzip \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    @anthropic-ai/claude-code \
    @openai/codex \
    opencode-ai

RUN useradd -ms /bin/bash dev
USER dev
WORKDIR /workspace

ENV BUN_INSTALL=/home/dev/.bun
ENV UV_NO_MODIFY_PATH=1
ENV PATH="/home/dev/.local/bin:/home/dev/.bun/bin:/usr/local/bin:${PATH}"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN curl -fsSL https://bun.sh/install | bash

ENTRYPOINT ["tini", "--"]
CMD ["bash"]
