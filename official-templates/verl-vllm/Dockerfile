# syntax=docker/dockerfile:1.6

# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"

# 默认跑 Verl，大模型写死为 Wan2.2
ARG VLLM_MODEL="Verl/Wan2.2"

ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"

# 资源相关（TP、大 context、显存利用率）
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

# FlashAttn / FlashInfer 开关（true/false）
ARG INSTALL_FLASHATTN="false"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales bash \
      software-properties-common tini && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python =====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    python -m pip install --no-cache-dir -U pip setuptools wheel

# ===== PyTorch: nightly cu126（适配 RTX 5090 / Blackwell）=====
RUN python -m pip install --no-cache-dir --pre \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu126

# ===== vLLM & HuggingFace =====
RUN python -m pip install --no-cache-dir \
      vllm \
      "transformers>=4.40,<5" \
      sentencepiece \
      huggingface_hub \
      hf_transfer

# ===== FlashAttn / FlashInfer（按需开启）=====
RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      set -euo pipefail; \
      echo "[FlashAttn] trying wheel..."; \
      python -m pip install --no-cache-dir flash-attn || \
      (echo "[FlashAttn] wheel failed, skipping"); \
    fi

# ===== 运行时参数写入环境变量 =====
ENV VLLM_MODEL=${VLLM_MODEL} \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

# ===== 入口脚本：只启动 vLLM OpenAI API =====
RUN cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[vLLM] Launching model: ${VLLM_MODEL}"
echo "[vLLM] host=${VLLM_HOST:-0.0.0.0} port=${VLLM_PORT:-8000}"
echo "[vLLM] TP_SIZE=${TP_SIZE:-1} MAX_MODEL_LEN=${MAX_MODEL_LEN:-32768} GPU_MEM_UTIL=${GPU_MEM_UTIL:-0.9}"

exec python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST:-0.0.0.0}" \
  --port "${VLLM_PORT:-8000}" \
  --model "${VLLM_MODEL}" \
  --download-dir "${HF_HOME:-/workspace/hf}" \
  --trust-remote-code \
  --tensor-parallel-size "${TP_SIZE:-1}" \
  --max-model-len "${MAX_MODEL_LEN:-32768}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL:-0.9}"
EOF

RUN chmod +x /entry.sh

# ===== Ports / Entry =====
EXPOSE 8000
WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/entry.sh"]
