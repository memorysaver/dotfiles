# .devcontainer

Dev container setup for running Claude Code, OpenCode, and Codex with Node, Bun, and Python+uv.
Based on Claude Code's devcontainer reference with an outbound firewall allowlist.

## Run

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm dev
```

Note: the firewall requires Docker capabilities `NET_ADMIN` and `NET_RAW`.

To start an OpenCode web server:

```bash
docker compose -f .devcontainer/docker-compose.yml run --rm --service-ports dev \
  opencode web --hostname 0.0.0.0 --port 4096
```
