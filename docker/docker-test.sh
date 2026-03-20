#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="memorysaver-dev"
NO_CACHE=""
RUN_AFTER=false

for arg in "$@"; do
  case "$arg" in
    --no-cache) NO_CACHE="--no-cache" ;;
    --run)      RUN_AFTER=true ;;
  esac
done

echo "Building $IMAGE from $REPO_ROOT ..."
docker build $NO_CACHE --progress=plain \
  -f "$REPO_ROOT/docker/Dockerfile" \
  -t "$IMAGE" "$REPO_ROOT"

echo "Build complete: $IMAGE"
$RUN_AFTER && docker run --rm -it "$IMAGE"
