# ==============================
# Base images for multi-arch
# ==============================
ARG BASE_IMAGE_AMD64="nvcr.io/nvidia/pytorch:24.10-py3"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

# ==============================
# Build-time args (和 buildx bake 对齐)
# ==============================
ARG PYTHON_VERSION="3.11"
ARG VLLM_PORT="8000"
ARG MODEL_NAME="Verl/Wan2.2"
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"
ARG INSTALL_FLASHATTN="false"

# ==============================
# Environment setup
# ==============================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    HF_HOME=/root/.cache/huggingface \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8

# 把 ARG 映射成 ENV，运行时也可以 -e 覆盖
ENV PYTHON_VERSION=${PYTHON_VERSION} \
    VLLM_PORT=${VLLM_PORT} \
    MODEL_NAME=${MODEL_NAME} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL} \
    INSTALL_FLASHATTN=${INSTALL_FLASHATTN}

# ==============================
# System dependencies
# ==============================
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash sudo curl wget git ca-certificates openssh-client \
    tmux vim zip unzip zsh \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==============================
# Python environment & vLLM
# ==============================
RUN python -m pip install --no-cache-dir -U pip setuptools wheel && \
    python -m pip install --no-cache-dir -U \
      "numpy<2" "pandas<2.2" "pyarrow<15" "scikit-learn<1.4" && \
    python -m pip install --no-cache-dir -U \
      vllm==0.11.0 "transformers>=4.45.0" "huggingface-hub>=0.25.0"

# 可选安装 flash-attn（需要时构建时传 INSTALL_FLASHATTN=true）
RUN if [ "${INSTALL_FLASHATTN}" = "true" ]; then \
      python -m pip install --no-cache-dir "flash-attn>=2.7.0" ; \
    fi

# ==============================
# Exposed Ports
# ==============================
# 22 预留给未来要加 sshd 的情况，8000 是 vLLM OpenAI API 端口
EXPOSE 22
EXPOSE ${VLLM_PORT}

# ==============================
# Default CMD
# ==============================
CMD ["/bin/bash", "-lc", "\
  echo \"[vLLM] Starting server for model ${MODEL_NAME}...\"; \
  exec python -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --port ${VLLM_PORT} \
    --model \"${MODEL_NAME}\" \
    --tensor-parallel-size ${TP_SIZE} \
    --max-model-len ${MAX_MODEL_LEN} \
    --gpu-memory-utilization ${GPU_MEM_UTIL} \
"]
