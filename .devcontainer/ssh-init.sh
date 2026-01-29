#!/usr/bin/env bash
set -euo pipefail

sudo /etc/init.d/ssh start > /tmp/sshd.log 2>&1 || true

exec "$@"
