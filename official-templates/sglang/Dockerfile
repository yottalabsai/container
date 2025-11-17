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

# TORCH 为空 = 使用稳定版 cu121（2.5.1）
ARG TORCH=""

# GPU 架构（H100=90, 4090=89, 5090=100）
ARG GPU_ARCH="100"

# 由 GPU_ARCH 自动推导
ARG TORCH_CUDA_ARCH_LIST="${GPU_ARCH}"
ARG CMAKE_CUDA_ARCHITECTURES="${GPU_ARCH}"

# 性能相关
ARG CMAKE_BUILD_PARALLEL_LEVEL=""
ARG PIP_DISABLE_PIP_VERSION_CHECK=1
ARG PYTHONUNBUFFERED=1

# HF / SGLang
ARG HF_HOME="/workspace/hf"
ARG HF_HUB_ENABLE_HF_TRANSFER=1
ARG SGLANG_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG SGLANG_HOST="0.0.0.0"
ARG SGLANG_PORT="30000"
ARG SGLANG_EXTRA=""
ARG SGLANG_PREFETCH="lazy"
ARG SGLANG_REVISION=""
ARG SGLANG_LOCAL_DIR=""

# ccache
ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS=1
ARG CCACHE_MAXSIZE="10G"

# ========================================
# 环境变量
# ========================================
ENV TZ=${TZ} \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} \
    CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES} \
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
# PyTorch
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ -n "${TORCH}" ]; then \
      echo "[TORCH] Installing custom: ${TORCH}"; \
      python3 -m pip install --no-cache-dir ${TORCH}; \
    else \
      echo "[TORCH] Installing stable cu121 (2.5.1)"; \
      python3 -m pip install --no-cache-dir \
        torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
        --index-url https://download.pytorch.org/whl/cu121; \
    fi

# ========================================
# Build Tools for sgl-kernel
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir -U \
      "cmake>=3.30" "scikit-build-core>=0.11" ninja packaging pybind11

# ========================================
# Build sgl-kernel
# ========================================
RUN --mount=type=cache,target=/root/.ccache \
    --mount=type=cache,target=/root/.cache/pip \
    bash -lc 'set -euxo pipefail; \
      : "${CMAKE_BUILD_PARALLEL_LEVEL:=$(nproc)}"; \
      export CMAKE_BUILD_PARALLEL_LEVEL; \
      export CMAKE_PREFIX_PATH="$(python3 -c "from torch.utils import cmake_prefix_path as p; print(p)")"; \
      python3 -m pip -v install --no-cache-dir --no-build-isolation \
        --config-settings=cmake.args="-G;Ninja" \
        --config-settings=cmake.define.CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
        --config-settings=cmake.define.CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES} \
        --config-settings=cmake.define.MSCCLPP_BUILD_APPS_NCCL=OFF \
        --config-settings=cmake.define.MSCCLPP_BUILD_TESTS=OFF \
        --config-settings=cmake.define.MSCCLPP_BUILD_PYTHON_BINDINGS=OFF \
        --config-settings=cmake.define.TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}" \
        "git+https://github.com/sgl-project/sglang.git#subdirectory=sgl-kernel" \
    '

# ========================================
# Install SGLang
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir --no-build-isolation \
      "sglang@git+https://github.com/sgl-project/sglang.git#subdirectory=python"

# ========================================
# Extra Runtime Deps
# ========================================
RUN python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai partial_json_parser \
      hf_transfer

# ========================================
# User
# ========================================
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ========================================
# Start Script
# ========================================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[SGLang] Model     : ${SGLANG_MODEL}"
echo "[SGLang] Host      : ${SGLANG_HOST}"
echo "[SGLang] Port      : ${SGLANG_PORT}"
echo "[Prefetch] Mode    : ${SGLANG_PREFETCH}"

if [ "${SGLANG_PREFETCH}" = "eager" ]; then
  python3 - <<'PY'
import os
from huggingface_hub import snapshot_download

model = os.environ["SGLANG_MODEL"]
local = os.environ.get("SGLANG_LOCAL_DIR") or None
rev   = os.environ.get("SGLANG_REVISION") or None

path = snapshot_download(
    repo_id=model,
    local_dir=local,
    revision=rev,
    local_dir_use_symlinks=False,
    resume_download=True,
)
print("Downloaded:", path)
PY
fi

exec uvicorn sglang.api.server:app \
    --host "${SGLANG_HOST}" \
    --port "${SGLANG_PORT}" \
    ${SGLANG_EXTRA}
EOF

RUN chmod +x /start.sh && chown ubuntu:ubuntu /start.sh

EXPOSE 30000
USER ubuntu
WORKDIR /home/ubuntu

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS "http://127.0.0.1:${SGLANG_PORT}/docs" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
