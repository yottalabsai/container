#!/usr/bin/env bash
set -euo pipefail

echo "[banana] post_start: starting go model gateway..."

# Default listen address
export ADDR="${ADDR:-:8080}"

mkdir -p /workspace/logs

# Start in background (start.sh keeps container alive)
nohup /opt/gateway/gateway \
  >> /workspace/logs/gateway.out.log \
  2>> /workspace/logs/gateway.err.log &

echo "[banana] go model gateway started (pid=$!) on ${ADDR}"
