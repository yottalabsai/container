# syntax=docker/dockerfile:1.7

ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ===== Build Args（可 --build-arg 覆盖）=====
ARG TZ="Asia/Singapore"
ARG PYTHON_VERSION="3.11"
ARG TORCH=""                             # 例：torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128
ARG TORCH_CUDA_ARCH_LIST="9.0"           # H100/H200=9.0, A100=8.0, 30xx=8.6, 4090=8.9
ARG CMAKE_CUDA_ARCHITECTURES="90"
ARG CMAKE_BUILD_PARALLEL_LEVEL=""        # 留空自动 nproc
ARG PIP_DISABLE_PIP_VERSION_CHECK=1
ARG PYTHONUNBUFFERED=1
ARG HF_HOME="/workspace/hf"
ARG HF_HUB_ENABLE_HF_TRANSFER=1
ARG SGLANG_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG SGLANG_HOST="0.0.0.0"
ARG SGLANG_PORT="30000"
ARG SGLANG_EXTRA=""
ARG CCACHE_DIR="/root/.ccache"
ARG CCACHE_COMPRESS=1
ARG CCACHE_MAXSIZE="10G"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env（运行时仍可 -e 覆盖）=====
ENV TZ=${TZ} \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} \
    CMAKE_BUILD_PARALLEL_LEVEL=${CMAKE_BUILD_PARALLEL_LEVEL} \
    PIP_DISABLE_PIP_VERSION_CHECK=${PIP_DISABLE_PIP_VERSION_CHECK} \
    PYTHONUNBUFFERED=${PYTHONUNBUFFERED} \
    HF_HOME=${HF_HOME} \
    HF_HUB_ENABLE_HF_TRANSFER=${HF_HUB_ENABLE_HF_TRANSFER} \
    SGLANG_MODEL=${SGLANG_MODEL} \
    SGLANG_HOST=${SGLANG_HOST} \
    SGLANG_PORT=${SGLANG_PORT} \
    SGLANG_EXTRA=${SGLANG_EXTRA} \
    CCACHE_DIR=${CCACHE_DIR} \
    CCACHE_COMPRESS=${CCACHE_COMPRESS} \
    CCACHE_MAXSIZE=${CCACHE_MAXSIZE} \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps（tzdata 先装避免交互）=====
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

# ===== Python（注意：--mount 只能放 RUN 前缀）=====
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

# ===== PyTorch（传 TORCH 用 nightly；否则默认稳定 cu121）=====
RUN --mount=type=cache,target=/root/.cache/pip \
    if [ -n "${TORCH}" ]; then \
      echo "Installing custom TORCH: ${TORCH}"; \
      python3 -m pip install --no-cache-dir ${TORCH}; \
    else \
      echo "Installing stable PyTorch (cu121)"; \
      python3 -m pip install --no-cache-dir \
        torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
        --index-url https://download.pytorch.org/whl/cu121; \
    fi

# ===== Build tools =====
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir -U \
      "cmake>=3.30" "scikit-build-core>=0.11" ninja packaging pybind11

# ===== Build sgl-kernel（单架构 + 关闭 MSCCL++ 可选组件 + 修 dlpack policy）=====
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.ccache \
    bash -lc 'set -euxo pipefail; \
      : "${CMAKE_BUILD_PARALLEL_LEVEL:=$(nproc)}"; export CMAKE_BUILD_PARALLEL_LEVEL; \
      echo ">>> nvcc:"; nvcc --version || true; \
      python3 -c "import torch; print(\"torch=\", torch.__version__); print(\"torch_cuda=\", torch.version.cuda)"; \
      export CMAKE_PREFIX_PATH="$(python3 -c "from torch.utils import cmake_prefix_path as p; print(p)")"; \
      echo ">>> CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}"; \
      echo ">>> TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST}  CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES}"; \
      python3 -m pip -v install --no-cache-dir --no-build-isolation \
        --config-settings=cmake.args="-G;Ninja" \
        --config-settings=cmake.define.CMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
        --config-settings=cmake.define.CMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES} \
        --config-settings=cmake.define.MSCCLPP_BUILD_APPS_NCCL=OFF \
        --config-settings=cmake.define.MSCCLPP_BUILD_TESTS=OFF \
        --config-settings=cmake.define.MSCCLPP_BUILD_PYTHON_BINDINGS=OFF \
        --config-settings=cmake.define.TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST}" \
        --config-settings=cmake.define.CMAKE_BUILD_TYPE=Release \
        --config-settings=cmake.define.CMAKE_POLICY_VERSION_MINIMUM=3.5 \
        --config-settings=build.verbose=true \
        "git+https://github.com/sgl-project/sglang.git#subdirectory=sgl-kernel" \
    '

# ===== Install SGLang =====
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir --no-build-isolation \
      "sglang@git+https://github.com/sgl-project/sglang.git#subdirectory=python"

# ===== Runtime deps =====
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai partial_json_parser \
      hf_transfer

# ===== User =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ===== Start script（若存在 /post_start.sh 就后台跑）=====
RUN cat >/start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
: "${SGLANG_MODEL:=Qwen/Qwen2.5-7B-Instruct}"
: "${SGLANG_HOST:=0.0.0.0}"
: "${SGLANG_PORT:=30000}"
: "${SGLANG_EXTRA:=}"
if [ -x /post_start.sh ]; then /post_start.sh & fi
echo "[SGLang] Model: ${SGLANG_MODEL}"
echo "[SGLang] Host : ${SGLANG_HOST}"
echo "[SGLang] Port : ${SGLANG_PORT}"
echo "[SGLang] Extra: ${SGLANG_EXTRA}"
exec uvicorn sglang.api.server:app --host "${SGLANG_HOST}" --port "${SGLANG_PORT}" ${SGLANG_EXTRA}
EOS
RUN chmod +x /start.sh && chown ubuntu:ubuntu /start.sh

EXPOSE 30000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
