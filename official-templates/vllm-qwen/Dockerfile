# ==============================
# Base & Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# Env (defaults, overridable at runtime)
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
    CMAKE_CUDA_ARCHITECTURES="120" \
    \
    # ------------------------------
    # vLLM runtime defaults (Pod 可覆盖)
    # ------------------------------
    VLLM_MODEL="Qwen/Qwen3-30B-A3B-Instruct-2507" \
    HF_MODEL_ID="Qwen/Qwen3-30B-A3B-Instruct-2507" \
    HF_TOKEN="" \
    VLLM_HOST="0.0.0.0" \
    VLLM_PORT="8001" \
    TP_SIZE="1" \
    MAX_MODEL_LEN="32768" \
    GPU_MEM_UTIL="0.92" \
    VLLM_TRUST_REMOTE_CODE="true" \
    VLLM_EXTRA_ARGS="" \
    VLLM_LOG="/workspace/vllm.log"

WORKDIR /

RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ==============================
# System deps
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
      tini sudo lsof \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# root SSH 目录（fix start.sh authorized_keys）
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# ==============================
# Create ubuntu user
# ==============================
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# SSH config
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
# PyTorch (nightly cu126 as you had)
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu126 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

# ==============================
# vLLM ecosystem
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm transformers sentencepiece "huggingface_hub[cli]" hf_transfer einops

# Optional accel (runtime install not recommended; keep build-time toggles if you want)
ARG INSTALL_FLASHATTN="false"
ARG INSTALL_FLASHINFER="false"

RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      python -m pip install --no-cache-dir flash-attn || true; fi

RUN if [[ "${INSTALL_FLASHINFER}" = "true" ]]; then \
      python -m pip install --no-cache-dir flashinfer || true; fi

# ==============================
# Copy platform start.sh (from bake context)
# ==============================
COPY --from=scripts start.sh /start.sh
RUN chmod +x /start.sh && mv /start.sh /start_platform.sh

# ==============================
# post_start.sh: download model (runtime) + start vLLM
# ==============================
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG="${VLLM_LOG:-/workspace/vllm.log}"
mkdir -p /workspace "${HF_HOME}"

MODEL_DIR="${HF_HOME}/${HF_MODEL_ID}"

echo "[post_start] HF_HOME=${HF_HOME}"
echo "[post_start] HF_MODEL_ID=${HF_MODEL_ID}"
echo "[post_start] VLLM_MODEL=${VLLM_MODEL}"
echo "[post_start] VLLM_HOST=${VLLM_HOST}"
echo "[post_start] VLLM_PORT=${VLLM_PORT}"
echo "[post_start] TP_SIZE=${TP_SIZE} MAX_MODEL_LEN=${MAX_MODEL_LEN} GPU_MEM_UTIL=${GPU_MEM_UTIL}"
echo "[post_start] VLLM_EXTRA_ARGS=${VLLM_EXTRA_ARGS}"

# ------------------------------
# Runtime model download (idempotent)
# ------------------------------
if [ ! -d "${MODEL_DIR}" ]; then
  echo "[post_start] Model not found, downloading ${HF_MODEL_ID} -> ${MODEL_DIR}"
  HF_ARGS=()
  if [ -n "${HF_TOKEN:-}" ]; then
    echo "[post_start] Using HF_TOKEN"
    HF_ARGS+=(--token "${HF_TOKEN}")
  fi
  huggingface-cli download \
    "${HF_MODEL_ID}" \
    --local-dir "${MODEL_DIR}" \
    --local-dir-use-symlinks False \
    --resume-download \
    "${HF_ARGS[@]}"
  echo "[post_start] Model download completed"
else
  echo "[post_start] Model already exists, skip download"
fi

# ------------------------------
# Port conflict handling
# ------------------------------
if lsof -i :"${VLLM_PORT}" >/dev/null 2>&1; then
  echo "[post_start] ERROR: Port ${VLLM_PORT} already in use. Set VLLM_PORT to another value (default is 8001)."
  lsof -i :"${VLLM_PORT}" || true
  exit 1
fi

# ------------------------------
# Start vLLM (OpenAI compatible server)
# ------------------------------
TRUST_FLAG=()
if [ "${VLLM_TRUST_REMOTE_CODE:-true}" = "true" ]; then
  TRUST_FLAG+=(--trust-remote-code)
fi

echo "[post_start] Starting vLLM with model path: ${MODEL_DIR}"

nohup python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --model "${MODEL_DIR}" \
  --download-dir "${HF_HOME}" \
  --tensor-parallel-size "${TP_SIZE}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL}" \
  "${TRUST_FLAG[@]}" \
  ${VLLM_EXTRA_ARGS} \
  >> "${LOG}" 2>&1 &

echo "[post_start] vLLM launched. Log: ${LOG}"
EOF

RUN chmod +x /post_start.sh

# ==============================
# start wrapper: platform start + post_start
# ==============================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 先跑平台原生启动（SSH/Nginx/用户注入等）
/start_platform.sh &

# 给平台服务一点点启动窗口（避免抢资源时偶发问题）
sleep 1

# 再启动 vLLM（含运行时下载）
/post_start.sh

# 保持容器前台：把平台脚本拉到前台（或阻塞）
wait -n
EOF

RUN chmod +x /start.sh

# ==============================
# Ports & Entrypoint
# ==============================
EXPOSE 22 8001

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]
