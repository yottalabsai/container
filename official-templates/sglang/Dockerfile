# ========================================
# Base image (can be overridden by bake)
# ========================================
ARG BASE_IMAGE="nvidia/cuda:12.1.1-devel-ubuntu22.04"
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

# ========================================
# Build arguments (all can be overridden by bake)
# ========================================
ARG TZ="UTC"
ARG PYTHON_VERSION="3.11"

# TORCH: leave empty by default = use stable 2.5.1+cu121 combination
ARG TORCH=""

# Performance-related
ARG CMAKE_BUILD_PARALLEL_LEVEL=""
ARG PIP_DISABLE_PIP_VERSION_CHECK=1
ARG PYTHONUNBUFFERED=1

# HF / SGLang
ARG HF_HOME="/workspace/hf"
ARG HF_HUB_ENABLE_HF_TRANSFER=1
ARG SGLANG_MODEL="Qwen/Qwen2.5-3B-Instruct"
ARG SGLANG_HOST="0.0.0.0"
ARG SGLANG_PORT="30000"

# ⚠️ No default value set here; must be passed in from outside
ARG SGLANG_EXTRA=""

# Prefetch / TP strategy: auto / lazy / eager
ARG SGLANG_PREFETCH="auto"
ARG SGLANG_TP="auto"

ARG SGLANG_REVISION=""
ARG SGLANG_LOCAL_DIR=""

# ccache
ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS="1"
ARG CCACHE_MAXSIZE="10G"

# ========================================
# Environment variables
# ========================================
ENV TZ=${TZ} \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=${HF_HOME} \
    HF_HUB_ENABLE_HF_TRANSFER=${HF_HUB_ENABLE_HF_TRANSFER} \
    PIP_DISABLE_PIP_VERSION_CHECK=${PIP_DISABLE_PIP_VERSION_CHECK} \
    PYTHONUNBUFFERED=${PYTHONUNBUFFERED} \
    CCACHE_DIR=${CCACHE_DIR} \
    CCACHE_COMPRESS=${CCACHE_COMPRESS} \
    CCACHE_MAXSIZE=${CCACHE_MAXSIZE} \
    SGLANG_MODEL=${SGLANG_MODEL} \
    SGLANG_HOST=${SGLANG_HOST} \
    SGLANG_PORT=${SGLANG_PORT} \
    SGLANG_EXTRA=${SGLANG_EXTRA} \
    SGLANG_PREFETCH=${SGLANG_PREFETCH} \
    SGLANG_TP=${SGLANG_TP} \
    SGLANG_REVISION=${SGLANG_REVISION} \
    SGLANG_LOCAL_DIR=${SGLANG_LOCAL_DIR}

ENV SGLANG_AUTOSTART="true"

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ========================================
# System Deps
# ========================================
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    set -eux; \
    apt-get update -y; \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; echo ${TZ} > /etc/timezone; \
    apt-get install -y --no-install-recommends tzdata; \
    apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates curl wget git git-lfs \
      locales bash sudo tini ffmpeg \
      build-essential ninja-build pkg-config ccache \
      libnuma-dev libibverbs-dev librdmacm-dev; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale; \
    rm -rf /var/lib/apt/lists/*

# ========================================
# root SSH directory (prevents tee authorized_keys error in start.sh)
# ========================================
RUN set -eux; \
    mkdir -p /root/.ssh; \
    chmod 700 /root/.ssh; \
    touch /root/.ssh/authorized_keys; \
    chmod 600 /root/.ssh/authorized_keys

# ========================================
# Python
# ========================================
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    bash -lc 'set -eux; \
      add-apt-repository -y ppa:deadsnakes/ppa; \
      apt-get update -y; \
      apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python; \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3; \
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
      /usr/bin/python3 /tmp/get-pip.py; rm -f /tmp/get-pip.py; \
      python3 -m pip install --no-cache-dir -U pip setuptools wheel \
    '

# ========================================
# PyTorch (default 2.5.1+cu121)
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    bash -lc 'set -eux; \
      if [ -n "${TORCH}" ]; then \
        echo "[TORCH] Installing custom: ${TORCH}"; \
        python3 -m pip install --no-cache-dir ${TORCH}; \
      else \
        echo "[TORCH] Installing stable cu121 (2.5.1)"; \
        python3 -m pip install --no-cache-dir \
          torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
          --index-url https://download.pytorch.org/whl/cu121; \
      fi \
    '

# ========================================
# sgl-kernel: wheel
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir sgl-kernel

# ========================================
# Install SGLang (GPU version)
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir "sglang[gpu]"

# ========================================
# Extra Runtime Deps
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai partial_json_parser \
      hf_transfer

# ========================================
# Optional ubuntu user (for future SSH access; default runtime is still root)
# ========================================
RUN useradd -ms /bin/bash ubuntu || true && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME" || true

# ========================================
# Start Script: /post_start.sh (runs as root)
# ========================================
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[SGLang] Model     : ${SGLANG_MODEL}"
echo "[SGLang] Host      : ${SGLANG_HOST}"
echo "[SGLang] Port      : ${SGLANG_PORT}"
echo "[Prefetch Env]    : ${SGLANG_PREFETCH:-auto}"
echo "[TP Env]          : ${SGLANG_TP:-auto}"
echo "$(date -u)"

# ---- Detect GPU count ----
GPU_COUNT=$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | wc -l || echo 1)
if [ "${GPU_COUNT}" -lt 1 ]; then
  GPU_COUNT=1
fi

# ---- Parse TP ----
TP_ENV="${SGLANG_TP:-auto}"
if [ "${TP_ENV}" = "auto" ]; then
  if [ "${GPU_COUNT}" -ge 2 ]; then
    TP_SIZE=${GPU_COUNT}
  else
    TP_SIZE=1
  fi
  echo "[TP] Auto-detected GPU count = ${GPU_COUNT}, use tp-size = ${TP_SIZE}"
else
  TP_SIZE="${TP_ENV}"
  echo "[TP] Use tp-size from env: ${TP_SIZE}"
fi

# ---- Parse Prefetch ----
PREFETCH_ENV="${SGLANG_PREFETCH:-auto}"
if [ "${PREFETCH_ENV}" = "auto" ]; then
  if [ "${GPU_COUNT}" -ge 2 ]; then
    PREFETCH_MODE="eager"
  else
    PREFETCH_MODE="lazy"
  fi
  echo "[Prefetch] Final Mode(auto) : ${PREFETCH_MODE}"
else
  PREFETCH_MODE="${PREFETCH_ENV}"
  echo "[Prefetch] Final Mode(env)  : ${PREFETCH_MODE}"
fi

echo "[SGLang] Extra Args: ${SGLANG_EXTRA:-<empty>}"

# ---- eager pre-download weights ----
if [ "${PREFETCH_MODE}" = "eager" ]; then
  python3 - <<'PY'
import os
from huggingface_hub import snapshot_download

model = os.environ["SGLANG_MODEL"]
local = os.environ.get("SGLANG_LOCAL_DIR") or None
rev = os.environ.get("SGLANG_REVISION") or None

print("[Prefetch] Downloading:", model, "->", local or "(hf cache)")
path = snapshot_download(
    repo_id=model,
    local_dir=local,
    revision=rev,
    local_dir_use_symlinks=False,
    resume_download=True,
)
print("[Prefetch] Downloaded to:", path)
PY
fi

# ---- Start sglang server ----
exec python3 -m sglang.launch_server \
    --model-path "${SGLANG_MODEL}" \
    --host "${SGLANG_HOST}" \
    --port "${SGLANG_PORT}" \
    --tp-size "${TP_SIZE}" \
    ${SGLANG_EXTRA}
EOF

# Key two lines: ensure /start.sh exists and directly reuses /post_start.sh
RUN chmod +x /post_start.sh && \
    ln -sf /post_start.sh /start.sh

# ========================================
# Entry script: /entrypoint.sh
# ========================================
RUN cat >/entrypoint.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${SGLANG_AUTOSTART:-true}" != "true" ]; then
  echo "[DEBUG] SGLANG_AUTOSTART=false → manual mode, SGLang will not start automatically."
  echo "[DEBUG] Container is ready. You can kubectl exec into it and run: /post_start.sh"
  exec tail -f /dev/null
fi

echo "[INFO] Auto-starting SGLang service..."
exec /post_start.sh
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 30000

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/entrypoint.sh"]
