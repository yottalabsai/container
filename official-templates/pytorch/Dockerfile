# ============================================================
# Yotta Verl vLLM Universal Image
# - 多架构支持：linux/amd64 + linux/arm64
# - 基础镜像：NVIDIA PyTorch 24.10（CUDA 12.8.1）
# - 修复 NumPy ABI 不兼容问题（强制 numpy<2）
# - 自动执行 /start.sh 或 fallback 到 vLLM API
# ============================================================

# ------------ 多架构基础镜像 ------------
ARG BASE_IMAGE_AMD64="nvcr.io/nvidia/pytorch:24.10-py3"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

# ------------ 架构选择 ------------
ARG TARGETARCH
FROM base_${TARGETARCH} AS base

# ============================================================
# 环境配置
# ============================================================
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1

# ---------------- 必要系统组件 ----------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash sudo curl wget ca-certificates git openssh-client \
    build-essential python3-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Python依赖环境（包含vLLM）
# ============================================================
RUN python -m pip install --no-cache-dir -U pip setuptools wheel && \
    python -m pip install --no-cache-dir -U \
        "numpy<2" \
        vllm==0.11.0 \
        "transformers>=4.45.0" \
        "huggingface-hub>=0.25.0" \
        accelerate \
        einops \
        pandas \
        scikit-learn \
        torchmetrics \
        sentencepiece \
        safetensors \
        pyarrow \
        bitsandbytes \
        peft

# ============================================================
# SSH / 权限 / Root 环境
# ============================================================
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

# ============================================================
# 端口定义（22 SSH / 8000 vLLM）
# ============================================================
EXPOSE 22 8000

# ============================================================
# 环境变量（运行时可覆盖）
# ============================================================
ENV MODEL_NAME="Wan-AI/Wan2.2-TI2V-5B" \
    HF_HOME="/root/.cache/huggingface" \
    VLLM_PORT="8000" \
    TP_SIZE="1" \
    MAX_MODEL_LEN="32768" \
    GPU_MEM_UTIL="0.90" \
    HUGGINGFACE_HUB_CACHE="/root/.cache/huggingface" \
    HF_TOKEN="" \
    JUPYTER_PASSWORD="abc123"

# ============================================================
# 启动逻辑：优先执行 /start.sh
# ============================================================
# 不再 COPY start.sh —— 保持容器无路径依赖
# 兼容容器内已有的 /start.sh，否则自动启动 vLLM API
CMD ["/bin/bash", "-lc", "\
set -euo pipefail; \
if [ -x /start.sh ]; then \
  echo '[Dockerfile] Found /start.sh, executing...'; \
  exec /start.sh; \
else \
  echo '[Dockerfile] /start.sh not found, fallback to vLLM'; \
  exec python -m vllm.entrypoints.openai.api_server \
    --host 0.0.0.0 \
    --port ${VLLM_PORT:-8000} \
    --model ${MODEL_NAME:-Wan-AI/Wan2.2-TI2V-5B} \
    --tensor-parallel-size ${TP_SIZE:-1} \
    --max-model-len ${MAX_MODEL_LEN:-32768} \
    --gpu-memory-utilization ${GPU_MEM_UTIL:-0.90}; \
fi"]

