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

# 默认：官方推荐栈 PyTorch 2.8.0 + cu121
# 如需自定义，可以在 bake 里覆盖 TORCH
ARG TORCH="torch==2.8.0+cu121 torchvision==0.21.0+cu121 torchaudio==2.8.0+cu121 --index-url https://download.pytorch.org/whl/cu121"

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
ARG SGLANG_PREFETCH="lazy"     # lazy / eager
ARG SGLANG_REVISION=""
ARG SGLANG_LOCAL_DIR=""

# ccache
ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS="1"
ARG CCACHE_MAXSIZE="10G"

# 可选：如果外面没传，就留空，让 sgl-kernel 自己探测
ARG TORCH_CUDA_ARCH_LIST=""
ARG CMAKE_CUDA_ARCHITECTURES=""

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
    bash -lc 'set -eux; \
      if [ -n "${TORCH}" ]; then \
        echo "[TORCH] Installing custom: ${TORCH}"; \
        python3 -m pip install --no-cache-dir ${TORCH}; \
      else \
        echo "[TORCH] Installing default torch==2.8.0+cu121"; \
        python3 -m pip install --no-cache-dir \
          torch==2.8.0+cu121 torchvision==0.21.0+cu121 torchaudio==2.8.0+cu121 \
          --index-url https://download.pytorch.org/whl/cu121; \
      fi \
    '

# ========================================
# （不再从源码编译 sgl-kernel，直接用 wheel）
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir sgl-kernel

# ========================================
# 安装 SGLang
# - 如果你要用固定版本，可以把 sglang 换成 sglang==0.x.y 或 git tag
# ========================================
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir \
      "sglang[gpu]"

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
# User
# ========================================
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ========================================
# Start Script（还是内联，不单独文件）
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
rev = os.environ.get("SGLANG_REVISION") or None

print("[Prefetch] Downloading:", model, "->", local or "(hf cache)")
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

# 官方推荐的启动方式：python -m sglang.launch_server
exec python3 -m sglang.launch_server \
    --model-path "${SGLANG_MODEL}" \
    --host "${SGLANG_HOST}" \
    --port "${SGLANG_PORT}" \
    --tp-size 1 \
    ${SGLANG_EXTRA}
EOF

RUN chmod +x /start.sh && chown ubuntu:ubuntu /start.sh

EXPOSE 30000
USER ubuntu
WORKDIR /home/ubuntu

HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS "http://127.0.0.1:${SGLANG_PORT}/docs" >/dev/null || exit 1

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
