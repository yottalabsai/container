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
# Environment setup
# ==============================
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV LANG=C.UTF-8

# ==============================
# System dependencies
# ==============================
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash sudo curl wget git ca-certificates openssh-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==============================
# Python environment setup
# ==============================
RUN python -m pip install --no-cache-dir -U pip setuptools wheel && \
    python -m pip install --no-cache-dir -U \
      "numpy<2" "pandas<2.2" "pyarrow<15" "scikit-learn<1.4" && \
    python -m pip install --no-cache-dir -U \
      vllm==0.11.0 "transformers>=4.45.0" "huggingface-hub>=0.25.0"

# ==============================
# Runtime configuration
# ==============================
ENV MODEL_NAME="Wan-AI/Wan2.2-TI2V-5B"
ENV VLLM_PORT=8000
ENV HF_HOME=/root/.cache/huggingface
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8
ENV JUPYTER_PASSWORD="abc123"

EXPOSE 22 8000

# ==============================
# Default CMD (no start.sh needed)
# ==============================
CMD ["/bin/bash", "-lc", "\
  echo '[vLLM] Starting server for model ${MODEL_NAME}...'; \
  python -m pip install --no-cache-dir -U 'numpy<2' 'pandas<2.2' 'pyarrow<15' 'scikit-learn<1.4'; \
  exec python -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --port ${VLLM_PORT:-8000} \
    --model ${MODEL_NAME} \
    --tensor-parallel-size ${TP_SIZE:-1} \
    --max-model-len ${MAX_MODEL_LEN:-32768} \
    --gpu-memory-utilization ${GPU_MEM_UTIL:-0.90} \
"]
