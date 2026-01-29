# .devcontainer

Dev container setup for running Claude Code, OpenCode, and Codex with Node, Bun, and Python+uv.

## Run

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm dev
```

To start an OpenCode web server:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --service-ports dev \
  opencode web --hostname 0.0.0.0 --port 4096
```
