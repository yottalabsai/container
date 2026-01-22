#!/usr/bin/env bash
set -euo pipefail

echo "[boot] PID=$$ starting at $(date -Is)"

HOST="${COMFYUI_HOST:-0.0.0.0}"
PORT="${COMFYUI_PORT:-8188}"
EXTRA_ARGS="${COMFYUI_EXTRA_ARGS:-}"

STORAGE="/workspace/storage"
COMFY_DIR="/home/ubuntu/ComfyUI"

if [ ! -d "$COMFY_DIR" ]; then
  echo "[boot][FATAL] ComfyUI dir not found: $COMFY_DIR" >&2
  exit 1
fi

# Optional: bind persistent storage into ComfyUI tree
if [ -d "$STORAGE" ]; then
  echo "[boot] storage detected at $STORAGE"
  mkdir -p "$COMFY_DIR/custom_nodes" "$COMFY_DIR/models" "$COMFY_DIR/user/default/workflows" || true

  if [ -d "$STORAGE/custom_nodes" ]; then
    echo "[boot] linking custom_nodes..."
    for d in "$STORAGE/custom_nodes"/*; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      rm -rf "$COMFY_DIR/custom_nodes/$name" 2>/dev/null || true
      ln -sfn "$d" "$COMFY_DIR/custom_nodes/$name"
      echo "  linked custom_node: $name"
    done
  fi

  if [ -d "$STORAGE/models" ]; then
    echo "[boot] linking models..."
    for d in "$STORAGE/models"/*; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      rm -rf "$COMFY_DIR/models/$name" 2>/dev/null || true
      ln -sfn "$d" "$COMFY_DIR/models/$name"
      echo "  linked model dir: $name"
    done
  fi

  if [ -d "$STORAGE/workflows" ]; then
    echo "[boot] linking workflows..."
    rm -rf "$COMFY_DIR/user/default/workflows" 2>/dev/null || true
    ln -sfn "$STORAGE/workflows" "$COMFY_DIR/user/default/workflows"
  fi
fi

echo "[boot] Starting ComfyUI..."
echo "[boot] dir=$COMFY_DIR listen=$HOST port=$PORT extra_args='${EXTRA_ARGS}'"

exec sudo -u ubuntu bash -lc "
  cd "$COMFY_DIR" &&       exec python3 -u main.py --listen "$HOST" --port "$PORT" ${EXTRA_ARGS}
"
