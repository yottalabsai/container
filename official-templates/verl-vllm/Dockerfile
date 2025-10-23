# ==============================
# Multi-Arch Base Definition
# ==============================
ARG BASE_IMAGE_AMD64="nvcr.io/nvidia/pytorch:24.10-py3"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

# ==============================
# System Environment Setup
# ==============================
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH=/usr/local/bin:$PATH \
    MODEL_NAME="Wan-AI/Wan2.2-TI2V-5B" \
    VLLM_PORT=8000 \
    TP_SIZE=1 \
    MAX_MODEL_LEN=32768 \
    GPU_MEM_UTIL=0.90

# ==============================
# Base OS Tools
# ==============================
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    wget \
    git \
    vim \
    ssh \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ==============================
# Python Environment Fixes
# ==============================
# 降级 NumPy / pandas / pyarrow / sklearn 以解决 ABI 冲突
RUN python -m pip install --no-cache-dir -U pip setuptools wheel \
    && python -m pip install --no-cache-dir -U \
        "numpy<2" \
        "pandas<2.2" \
        "pyarrow<15" \
        "scikit-learn<1.4"

# ==============================
# vLLM + Transformers + HuggingFace
# ==============================
RUN python -m pip install --no-cache-dir -U \
      vllm==0.11.0 \
      "transformers>=4.45.0" \
      "huggingface-hub>=0.25.0" \
      accelerate \
      sentencepiece \
      safetensors

# ==============================
# Default SSH Setup
# ==============================
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

# ==============================
# Copy Start Script
# ==============================
# （如你已有 /start.sh，可以保留；否则创建默认逻辑）
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ==============================
# Default Entrypoint
# ==============================
WORKDIR /workspace
EXPOSE 22 8000

CMD ["/bin/bash", "-lc", "\
    set -euo pipefail && \
    install -d -m 700 -o root -g root /root/.ssh && \
    echo 'Starting Verl/Wan2.2-TI2V-5B with vLLM...' && \
    if [ -x /start.sh ]; then \
        exec /start.sh; \
    else \
        exec python -m vllm.entrypoints.openai.api_server \
            --host 0.0.0.0 \
            --port ${VLLM_PORT:-8000} \
            --model ${MODEL_NAME} \
            --tensor-parallel-size ${TP_SIZE:-1} \
            --max-model-len ${MAX_MODEL_LEN:-32768} \
            --gpu-memory-utilization ${GPU_MEM_UTIL:-0.90}; \
    fi"]

