# ==============================
# Base & Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"

ARG VLLM_MODEL="Qwen/Qwen2.5-3B-Instruct"
ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"

ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

ARG INSTALL_FLASHATTN="false"
ARG INSTALL_FLASHINFER="false"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# Env
# ==============================
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    SHELL=/bin/bash \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120"

WORKDIR /

RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ==============================
# 系统依赖
# ==============================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx \
      openssh-server openssh-client \
      tmux vim zsh zip unzip less procps net-tools htop \
      tini sudo \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# root SSH 目录（fix start.sh authorized_keys）
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# ==============================
# 创建 ubuntu 用户
# ==============================
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# SSH 配置
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# ==============================
# Python / pip
# ==============================
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      /usr/bin/python /tmp/get-pip.py || true)

RUN python -m pip --version || \
    (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

RUN python -m pip install --no-cache-dir -U pip setuptools wheel

# ==============================
# PyTorch cu126
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu126 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

# ==============================
# vLLM 生态
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm transformers sentencepiece huggingface_hub hf_transfer einops

# Flash 加速（按需）
RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      python -m pip install flash-attn || true; fi

RUN if [[ "${INSTALL_FLASHINFER}" = "true" ]]; then \
      python -m pip install flashinfer || true; fi

# ==============================
# vLLM 环境变量
# ==============================
ENV VLLM_MODEL=${VLLM_MODEL} \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

# ==============================
# Copy 平台 start.sh（来自 bake scripts context）
# ==============================
COPY --from=scripts start.sh /start.sh
RUN chmod +x /start.sh

# ==============================
# post_start.sh：容器最后启动 vLLM
# ==============================
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -e

echo "[post_start] Starting vLLM model: ${VLLM_MODEL}"

nohup python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --model "${VLLM_MODEL}" \
  --download-dir "${HF_HOME}" \
  --trust-remote-code \
  --tensor-parallel-size "${TP_SIZE}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL}" \
  >> /workspace/vllm.log 2>&1 &

echo "[post_start] vLLM launched. Log: /workspace/vllm.log"
EOF

RUN chmod +x /post_start.sh

# ==============================
# Ports & Entrypoint
# ==============================
EXPOSE 22 8000

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]
