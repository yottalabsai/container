# ==============================
# Multi-arch base (amd64/arm64)
# ==============================
ARG BASE_IMAGE_AMD64="nvcr.io/nvidia/pytorch:24.10-py3"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

# ==============================
# Env (runtime-overridable)
# ==============================
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    VLLM_PORT=8000 \
    MODEL_NAME="Wan-AI/Wan2.2-TI2V-5B" \
    TP_SIZE=1 \
    MAX_MODEL_LEN=32768 \
    GPU_MEM_UTIL=0.90 \
    VLLM_EXTRA=""

# ==============================
# System deps
# ==============================
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash sudo curl wget ca-certificates git openssh-client build-essential \
    && rm -rf /var/lib/apt/lists/*

# ==============================
# Python deps (fix NumPy ABI)
# ==============================
RUN python -m pip install --no-cache-dir -U pip setuptools wheel && \
    python -m pip install --no-cache-dir -U \
      "numpy<2" \
      "pandas<2.2" \
      "pyarrow<15" \
      "scikit-learn<1.4"

# ==============================
# vLLM + Transformers stack
# （版本可按需调整；与日志中的 0.11.0 对齐）
# ==============================
RUN python -m pip install --no-cache-dir -U \
      vllm==0.11.0 \
      "transformers>=4.45.0" \
      "huggingface-hub>=0.25.0" \
      accelerate sentencepiece safetensors

# ==============================
# Bring your start.sh (path is relative to build context root)
# 目录结构：official-templates/verl-vllm/Dockerfile
#         ../container-template/start.sh
# ==============================
COPY ../container-template/start.sh /start.sh
RUN chmod +x /start.sh

# ==============================
# Runtime
# ==============================
WORKDIR /workspace
EXPOSE 8000
# 如确需 SSH 才开放 22： EXPOSE 22

# 保留 NVIDIA ENTRYPOINT，仅提供非空 CMD。若 /start.sh 存在则用它，否则直接启动 vLLM。
CMD ["/bin/bash","-lc","set -euo pipefail && \
  echo '[startup] MODEL='${MODEL_NAME}' PORT='${VLLM_PORT}' TP='${TP_SIZE}' MAXLEN='${MAX_MODEL_LEN}' GPUUtil='${GPU_MEM_UTIL} && \
  if [ -x /start.sh ]; then \
    exec /start.sh; \
  else \
    exec python -m vllm.entrypoints.openai.api_server \
      --host 0.0.0.0 \
      --port ${VLLM_PORT} \
      --model ${MODEL_NAME} \
      --tensor-parallel-size ${TP_SIZE} \
      --max-model-len ${MAX_MODEL_LEN} \
      --gpu-memory-utilization ${GPU_MEM_UTIL} \
      ${VLLM_EXTRA}; \
  fi"]
