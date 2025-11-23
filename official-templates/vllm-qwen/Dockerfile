# ==============================
# Base & Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"

# 默认模型：Qwen2.5-3B-Instruct（开源，无需 token）
ARG VLLM_MODEL="Qwen/Qwen2.5-3B-Instruct"
ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"

# 资源相关（TP、大 context、显存利用率）
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

# FlashAttn / FlashInfer 开关（true/false）
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
    # Blackwell / RTX 5090（sm_120）
    TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120"

WORKDIR /

# 保证 workspace 可写
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ==============================
# 系统依赖 + SSH + 工具
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
      tini \
      sudo \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# 创建非 root 用户
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# SSH 配置（允许密码登录，禁止 root 登录）
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# ==============================
# Python 环境
# ==============================
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      /usr/bin/python /tmp/get-pip.py || true) && \
    rm -f /tmp/get-pip.py

# 兜底：如果前面 pip 装失败，这里再补一刀
RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip) && \
    python -m pip install --no-cache-dir -U pip setuptools wheel

# ==============================
# PyTorch: nightly cu126（适配 5090 / Blackwell）
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu126 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

# ==============================
# vLLM & HuggingFace 生态
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm \
      "transformers>=4.40,<5" \
      sentencepiece \
      huggingface_hub \
      hf_transfer \
      einops

# ==============================
# FlashAttn / FlashInfer（按需开启）
# ==============================
RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      set -euo pipefail; \
      echo "[FlashAttn] trying wheel..."; \
      python -m pip install --no-cache-dir flash-attn || \
      (echo "[FlashAttn] wheel failed, skipping"); \
    fi

RUN if [[ "${INSTALL_FLASHINFER}" = "true" ]]; then \
      set -euo pipefail; \
      echo "[FlashInfer] trying wheel..."; \
      python -m pip install --no-cache-dir flashinfer || \
      (echo "[FlashInfer] wheel failed, skipping"); \
    fi

# ==============================
# 运行时参数写入环境变量
# ==============================
ENV VLLM_MODEL=${VLLM_MODEL} \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

# ==============================
# 入口脚本：sshd + vLLM（vLLM 用 ubuntu 用户跑）
# ==============================
RUN cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[init] starting sshd..."
/usr/sbin/sshd

echo "[vLLM] Launching model: ${VLLM_MODEL}"
echo "[vLLM] host=${VLLM_HOST:-0.0.0.0} port=${VLLM_PORT:-8000}"
echo "[vLLM] TP_SIZE=${TP_SIZE:-1} MAX_MODEL_LEN=${MAX_MODEL_LEN:-32768} GPU_MEM_UTIL=${GPU_MEM_UTIL:-0.92}"
echo "[vLLM] HF_HOME=${HF_HOME:-/workspace/hf}"

# 以非 root 用户运行 vLLM
exec su -s /bin/bash -c "
  python -m vllm.entrypoints.openai.api_server \
    --host \"${VLLM_HOST:-0.0.0.0}\" \
    --port \"${VLLM_PORT:-8000}\" \
    --model \"${VLLM_MODEL}\" \
    --download-dir \"${HF_HOME:-/workspace/hf}\" \
    --trust-remote-code \
    --tensor-parallel-size \"${TP_SIZE:-1}\" \
    --max-model-len \"${MAX_MODEL_LEN:-32768}\" \
    --gpu-memory-utilization \"${GPU_MEM_UTIL:-0.92}\"
" "${UBUNTU_USER}"
EOF

RUN chmod +x /entry.sh && chown ${UBUNTU_USER}:${UBUNTU_USER} /entry.sh && \
    chown -R ${UBUNTU_USER}:${UBUNTU_USER} /workspace "$HF_HOME"

# ==============================
# 暴露端口 & Entrypoint
# ==============================
EXPOSE 22 8000

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/entry.sh"]
