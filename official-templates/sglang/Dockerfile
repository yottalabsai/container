# syntax=docker/dockerfile:1.7

# ========================================
# 基础镜像（可由 bake 覆盖）
# ========================================
ARG BASE_IMAGE="nvidia/cuda:12.1.1-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ========================================
# 构建参数（全部允许 bake 覆盖）
# ========================================
ARG TZ="UTC"
ARG PYTHON_VERSION="3.11"

# TORCH：默认留空 = 使用稳定 2.5.1+cu121 组合
ARG TORCH=""

# 性能相关
ARG CMAKE_BUILD_PARALLEL_LEVEL=""
ARG PIP_DISABLE_PIP_VERSION_CHECK=1
ARG PYTHONUNBUFFERED=1

# HF / SGLang
ARG HF_HOME="/workspace/hf"
ARG HF_HUB_ENABLE_HF_TRANSFER=1
ARG SGLANG_MODEL="Qwen/Qwen2.5-3B-Instruct"
ARG SGLANG_HOST="0.0.0.0"
ARG SGLANG_PORT="30000"

# 1️⃣ TP：允许外部覆盖；留空 = 自动按 GPU 数量推 tp-size
ARG SGLANG_TP_SIZE=""

# 2️⃣ 预拉模式：
#   lazy  = 不预拉，第一次请求时再拉
#   eager = 容器启动时就 snapshot_download
#   auto  = 自动策略（默认：多卡 / 大卡用 eager，单卡用 lazy）
ARG SGLANG_PREFETCH="auto"

ARG SGLANG_REVISION=""
ARG SGLANG_LOCAL_DIR=""

# ccache
ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS="1"
ARG CCACHE_MAXSIZE="10G"

# ========================================
# 环境变量
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
    SGLANG_TP_SIZE=${SGLANG_TP_SIZE} \
    SGLANG_PREFETCH=${SGLANG_PREFETCH} \
    SGLANG_REVISION=${SGLANG_REVISION} \
    SGLANG_LOCAL_DIR=${SGLANG_LOCAL_DIR}

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
# root SSH 目录（避免外面 echo 公钥时报错）
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
# PyTorch（默认 2.5.1+cu121）
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
# sgl-kernel：用 wheel，避免自己编译
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir sgl-kernel

# ========================================
# 安装 SGLang（GPU 版本）
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
# 可选 ubuntu 用户（以后要 ssh 用；现在默认还是 root 跑）
# ========================================
RUN useradd -ms /bin/bash ubuntu || true && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME" || true

# ========================================
# Start Script：自动 TP + 自适应 lazy/eager
# ========================================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[SGLang] Model     : ${SGLANG_MODEL}"
echo "[SGLang] Host      : ${SGLANG_HOST}"
echo "[SGLang] Port      : ${SGLANG_PORT}"
echo "[Prefetch Env]    : ${SGLANG_PREFETCH:-auto}"
echo "[TP Env]          : ${SGLANG_TP_SIZE:-<empty>}"

date

# ---------- 1) 自动推断 tp-size ----------
TP_SIZE_EFFECTIVE=""
if [ -n "${SGLANG_TP_SIZE:-}" ]; then
  TP_SIZE_EFFECTIVE="${SGLANG_TP_SIZE}"
  echo "[TP] Use env SGLANG_TP_SIZE = ${TP_SIZE_EFFECTIVE}"
else
  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "${GPU_COUNT}" ] || [ "${GPU_COUNT}" -lt 1 ]; then
      GPU_COUNT=1
    fi
  else
    GPU_COUNT=1
  fi

  TP_SIZE_EFFECTIVE="${GPU_COUNT}"
  echo "[TP] Auto-detected GPU count = ${GPU_COUNT}, use tp-size = ${TP_SIZE_EFFECTIVE}"
fi

# ---------- 2) lazy/eager 自适应 ----------
PREFETCH_MODE="${SGLANG_PREFETCH:-auto}"

if [ "${PREFETCH_MODE}" = "auto" ]; then
  # 简单策略：
  # - 多卡（>=2）默认 eager：一次性把权重拉好，适合 5090 双卡这类长跑服务
  # - 单卡默认 lazy：减小启动时间
  if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_COUNT_PREF=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "${GPU_COUNT_PREF}" ] || [ "${GPU_COUNT_PREF}" -lt 1 ]; then
      GPU_COUNT_PREF=1
    fi
  else
    GPU_COUNT_PREF=1
  fi

  if [ "${GPU_COUNT_PREF}" -ge 2 ]; then
    PREFETCH_MODE="eager"
  else
    PREFETCH_MODE="lazy"
  fi
  echo "[Prefetch] AUTO resolved to: ${PREFETCH_MODE} (gpu-count=${GPU_COUNT_PREF})"
fi

echo "[Prefetch] Final Mode: ${PREFETCH_MODE}"

# ---------- 3) 如果是 eager / auto->eager，就提前 snapshot_download ----------
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

# ---------- 4) 后端选择兜底：默认禁用 flashinfer，走 torch_native/torch ----------
# 如果你想玩高级后端，可以在环境变量里覆盖：
#   SGLANG_EXTRA="--attention-backend triton --sampling-backend flashinfer"
if [ -z "${SGLANG_EXTRA:-}" ]; then
  SGLANG_EXTRA="--attention-backend torch_native --sampling-backend pytorch"
  echo "[SGLang] No extra args provided, use default: ${SGLANG_EXTRA}"
else
  echo "[SGLang] Use custom extra args: ${SGLANG_EXTRA}"
fi

# ---------- 5) 启动 SGLang ----------
echo "[SGLang] Launching server..."
exec python3 -m sglang.launch_server \
    --model-path "${SGLANG_MODEL}" \
    --host "${SGLANG_HOST}" \
    --port "${SGLANG_PORT}" \
    --tp-size "${TP_SIZE_EFFECTIVE}" \
    ${SGLANG_EXTRA} \
    2>&1 | tee /workspace/sglang.log
EOF

RUN chmod +x /start.sh

EXPOSE 30000

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
