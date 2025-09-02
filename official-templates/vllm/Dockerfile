# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION=3.11
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
ARG VLLM_PIP="vllm"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    HF_HOME=/workspace/hf \
    TRANSFORMERS_CACHE=/workspace/hf \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=8000 \
    VLLM_MODEL=Qwen/Qwen2.5-7B-Instruct

WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===== System deps =====
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales sudo tini && \
    git lfs install && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python =====
RUN add-apt-repository ppa:deadsnakes/ppa -y && apt-get update -y && \
    apt-get install -y python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python && \
    pip install --upgrade pip setuptools wheel

# ===== Torch =====
RUN pip install --no-cache-dir ${TORCH}

# ===== vLLM =====
RUN pip install --no-cache-dir ${VLLM_PIP} \
    fastapi uvicorn uvloop orjson psutil zmq huggingface_hub transformers sentencepiece hf_transfer

# ===== User =====
RUN useradd -ms /bin/bash ubuntu && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu

# ===== Post start =====
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace

sudo -u ubuntu nohup python3 -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --model "${VLLM_MODEL}" \
  --download-dir "${HF_HOME}" \
  --trust-remote-code \
  ${VLLM_EXTRA:-} >> "$LOG" 2>&1 &

echo "vLLM started on ${VLLM_HOST}:${VLLM_PORT}, log: $LOG"
EOF
RUN chmod +x /post_start.sh

ENTRYPOINT ["/bin/bash", "/post_start.sh"]