ARG BASE_IMAGE_AMD64="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

ARG PYTHON_VERSION="3.11"
ARG VLLM_PORT="8000"

# 可选组件
ARG INSTALL_FLASHATTN="false"

# 运行参数（可运行时 -e 覆盖）
ARG MODEL_NAME="Verl/Wan2.2"
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

SHELL ["/bin/bash","-o","pipefail","-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    VLLM_PORT=${VLLM_PORT} \
    MODEL_NAME=${MODEL_NAME} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

# ---- OS 依赖 ----
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git curl ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 software-properties-common && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    rm -rf /var/lib/apt/lists/*

# ---- Python（容错：若基座已有则跳过）----
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && /usr/bin/python /tmp/get-pip.py || true) && \
    python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

# ---- pip 基础 & vLLM 安装 ----
RUN python -m pip install --upgrade pip wheel setuptools && \
    python -m pip install "vllm>=0.5.0" "uvicorn>=0.30" "fastapi>=0.110"

# 可选：FlashAttention（部分环境有 wheel；安装失败不阻断）
RUN if [[ "${INSTALL_FLASHATTN}" == "true" ]]; then \
      python -m pip install "flash-attn>=2.5.8" || echo "[WARN] flash-attn 安装失败，已跳过"; \
    fi

# ---- 暴露端口 ----
EXPOSE ${VLLM_PORT}

# ---- 启动（OpenAI 兼容 API）----
CMD ["bash","-lc","python -m vllm.entrypoints.openai.api_server \
  --host 0.0.0.0 \
  --port ${VLLM_PORT} \
  --model ${MODEL_NAME} \
  --tensor-parallel-size ${TP_SIZE} \
  --max-model-len ${MAX_MODEL_LEN} \
  --gpu-memory-utilization ${GPU_MEM_UTIL}"]
