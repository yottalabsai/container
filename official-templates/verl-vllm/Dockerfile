# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"

# 默认跑 Verl，大模型这里就定死 Wan2.2
ARG VLLM_MODEL="Verl/Wan2.2"

# 可选扩展参数（先留着，暂时不用动）
ARG VLLM_EXTRA=""
ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"

# 资源相关（TP、大 context、显存利用率）
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

# FlashInfer 编译开关（1 = 安装）
ARG INSTALL_FLASHINFER="0"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    HF_HOME=/workspace/hf \
    TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120" \
    VLLM_MODEL=${VLLM_MODEL} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash \
      software-properties-common openssh-server nginx sudo tini ffmpeg \
      build-essential pkg-config ninja-build && \
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

# ===== FlashInfer（5090 / Blackwell 建议开启）=====
RUN if [[ "${INSTALL_FLASHINFER}" = "1" ]]; then \
      set -euo pipefail; \
      echo "[FlashInfer] trying wheel..."; \
      (python -m pip install --no-cache-dir flashinfer && echo "[FlashInfer] wheel OK") || \
      (echo "[FlashInfer] wheel failed, building from source..." && \
       git clone --recursive https://github.com/AnswerDotAI/FlashInfer.git /tmp/flashinfer && \
       export TORCH_CUDA_ARCH_LIST="12.0" CMAKE_CUDA_ARCHITECTURES="120" && \
       python -m pip install -v /tmp/flashinfer/python && \
       rm -rf /tmp/flashinfer && \
       echo "[FlashInfer] built from source OK"); \
    fi

# ===== SSH（可选，占位一下）=====
RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh

# ===== post_start.sh（唯一启动脚本：起 Verl vLLM）=====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace

echo "[vLLM] Launching model: ${VLLM_MODEL}"
echo "[vLLM] TP_SIZE=${TP_SIZE}, MAX_MODEL_LEN=${MAX_MODEL_LEN}, GPU_MEM_UTIL=${GPU_MEM_UTIL}"

nohup python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST:-0.0.0.0}" \
  --port "${VLLM_PORT:-8000}" \
  --model "${VLLM_MODEL}" \
  --download-dir "${HF_HOME}" \
  --trust-remote-code \
  --tensor-parallel-size "${TP_SIZE:-1}" \
  --max-model-len "${MAX_MODEL_LEN:-32768}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL:-0.9}" \
  ${VLLM_EXTRA} >> "$LOG" 2>&1 &

echo "[vLLM] Waiting for readiness..."
for i in {1..20}; do
  if curl -fsS "http://127.0.0.1:${VLLM_PORT:-8000}/v1/models" >/dev/null; then
    echo "[vLLM] Ready."
    exit 0
  fi
  echo "waiting... ($i)"
  sleep 1
done

echo "WARN: vLLM may not be ready; check $LOG"
exit 0
EOS

RUN chmod +x /post_start.sh

# ===== Ports / Entry =====
EXPOSE 8000
WORKDIR /root
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/post_start.sh && sleep infinity"]
