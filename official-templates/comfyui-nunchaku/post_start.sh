#!/usr/bin/env bash
set -euo pipefail

# start.sh (immutable) will call /post_start.sh at the end.
# We keep post_start minimal: spawn /boot.sh in background and return.

echo "[post_start] Starting ComfyUI-Nunchaku via /boot.sh ..."

# Run in background so start.sh can continue to "sleep infinity"
/boot.sh &
disown || true

echo "[post_start] Spawned. Web UI should be available on :${COMFYUI_PORT:-8188}"
