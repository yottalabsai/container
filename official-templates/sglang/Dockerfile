# ============================================================
# 基础镜像（CUDA 12.1.1 + Ubuntu 22.04）
# ============================================================
ARG BASE_IMAGE="nvidia/cuda:12.1.1-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ============================================================
# 构建参数
# ============================================================
ARG TZ="UTC"
ARG PYTHON_VERSION="3.11"
ARG TORCH=""

ARG HF_HOME="/workspace/hf"
ARG HF_HUB_ENABLE_HF_TRANSFER=1

ARG SGLANG_MODEL="Qwen/Qwen2.5-3B-Instruct"
ARG SGLANG_HOST="0.0.0.0"
ARG SGLANG_PORT="30000"

# extra 默认允许为空；但 Dockerfile 内部会固定补充 trust-remote-code
ARG SGLANG_EXTRA=""

ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS="1"
ARG CCACHE_MAXSIZE="10G"

# ============================================================
# 环境变量
# ============================================================
ENV TZ=${TZ} \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=${HF_HOME} \
    HF_HUB_ENABLE_HF_TRANSFER=${HF_HUB_ENABLE_HF_TRANSFER} \
    CCACHE_DIR=${CCACHE_DIR} \
    CCACHE_COMPRESS=${CCACHE_COMPRESS} \
    CCACHE_MAXSIZE=${CCACHE_MAXSIZE} \
    SGLANG_MODEL=${SGLANG_MODEL} \
    SGLANG_HOST=${SGLANG_HOST} \
    SGLANG_PORT=${SGLANG_PORT} \
    SGLANG_EXTRA=${SGLANG_EXTRA}

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ============================================================
# System Deps
# ============================================================
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

# ============================================================
# SSH（避免 authorized_keys 再报错）
# ============================================================
RUN set -eux; \
    mkdir -p /root/.ssh; \
    chmod 700 /root/.ssh; \
    touch /root/.ssh/authorized_keys; \
    chmod 600 /root/.ssh/authorized_keys;

# ============================================================
# Python
# ============================================================
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

# ============================================================
# PyTorch
# ============================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    bash -lc 'set -eux; \
      if [ -n "${TORCH}" ]; then \
        python3 -m pip install --no-cache-dir ${TORCH}; \
      else \
        python3 -m pip install --no-cache-dir \
          torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
          --index-url https://download.pytorch.org/whl/cu121; \
      fi \
    '

# ============================================================
# sglang 依赖
# ============================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir sgl-kernel "sglang[gpu]"

# ============================================================
# HF & runtime deps
# ============================================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pyzmq pybase64 hf_transfer openai partial_json_parser

# ============================================================
# ubuntu 用户
# ============================================================
RUN useradd -ms /bin/bash ubuntu || true && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME" || true

# ============================================================
# Start Script（自动 TP + auto Prefetch + trust remote code）
# ============================================================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[SGLang] Model     : ${SGLANG_MODEL}"
echo "[SGLang] Host      : ${SGLANG_HOST}"
echo "[SGLang] Port      : ${SGLANG_PORT}"
echo "[Prefetch Env]    : ${SGLANG_PREFETCH:-auto}"
echo "[TP Env]          : ${SGLANG_TP:-auto}"
date

# --------------------------------------------
# 自动探测 GPU 数量 => TP 自动选择
# --------------------------------------------
GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
if [ "${SGLANG_TP:-auto}" = "auto" ]; then
  if [ "${GPU_COUNT}" -ge 2 ]; then
    TP="${GPU_COUNT}"
  else
    TP=1
  fi
else
  TP="${SGLANG_TP}"
fi
echo "[TP] Auto-detected GPU count = ${GPU_COUNT}, use tp-size = ${TP}"

# --------------------------------------------
# 自动 Prefetch
# 单卡：lazy
# 多卡：eager
# --------------------------------------------
if [ "${SGLANG_PREFETCH:-auto}" = "auto" ]; then
  if [ "${GPU_COUNT}" -ge 2 ]; then
    PREFETCH="eager"
  else
    PREFETCH="lazy"
  fi
else
  PREFETCH="${SGLANG_PREFETCH}"
fi
echo "[Prefetch] Final Mode: ${PREFETCH}"

# --------------------------------------------
# eager 模式预加载
# --------------------------------------------
if [ "${PREFETCH}" = "eager" ]; then
python3 - <<PY
import os
from huggingface_hub import snapshot_download

model = os.environ["SGLANG_MODEL"]
print("[Prefetch] Downloading:", model)
path = snapshot_download(repo_id=model, local_dir="/workspace/hf", local_dir_use_symlinks=False)
print("[Prefetch] Downloaded to:", path)
PY
fi

# --------------------------------------------
# 补充 trust-remote-code（强制启用）
# --------------------------------------------
EXTRA_ARGS="--trust-remote-code ${SGLANG_EXTRA:-}"

echo "[SGLang] Extra Args: ${EXTRA_ARGS}"

# --------------------------------------------
# 启动服务
# --------------------------------------------
exec python3 -m sglang.launch_server \
  --model-path "${SGLANG_MODEL}" \
  --host "${SGLANG_HOST}" \
  --port "${SGLANG_PORT}" \
  --tp-size "${TP}" \
  ${EXTRA_ARGS} \
  2>&1 | tee /workspace/sglang.log
EOF

RUN chmod +x /start.sh

EXPOSE 30000
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
