# ==============================
# Base & Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"

# Optional build-time installs
ARG INSTALL_FLASHATTN="false"
ARG INSTALL_FLASHINFER="false"

# Model ID also as a build argument (used with HF_MODEL_ID in bake)
ARG HF_MODEL_ID="Qwen/Qwen3-30B-A3B-Instruct-2507"
# Build-time HuggingFace Token
ARG HF_TOKEN

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
    # vLLM runtime defaults (overridable at Pod level)
    # ------------------------------
    VLLM_MODEL="Qwen/Qwen3-30B-A3B-Instruct-2507" \
    HF_MODEL_ID="${HF_MODEL_ID}" \
    VLLM_HOST="0.0.0.0" \
    VLLM_PORT="8001" \
    TP_SIZE="1" \
    MAX_MODEL_LEN="32768" \
    GPU_MEM_UTIL="0.92" \
    VLLM_TRUST_REMOTE_CODE="true" \
    VLLM_EXTRA_ARGS="" \
    VLLM_LOG="/workspace/vllm.log" \
    \
    # ------------------------------
    # MoltBot/OpenClaw defaults
    # ------------------------------
    OPENCLAW_GATEWAY_PORT="18789" \
    OPENCLAW_AUTH_TOKEN="clawdbot" \
    OPENCLAW_LOG="/workspace/openclaw.log"

WORKDIR /

RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ==============================
# System deps (UTC fixed timezone)
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
      tini sudo lsof gnupg2 \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "Etc/UTC" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# root SSH directory (for platform key injection)
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
# Node.js 22 Installation
# ==============================
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    node --version && \
    npm --version && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
      /usr/bin/python /tmp/get-pip.py || true) && \
    rm -f /tmp/get-pip.py

RUN python -m pip --version || \
    (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

RUN python -m pip install --no-cache-dir -U pip setuptools wheel

# ==============================
# PyTorch (nightly cu128)
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu128 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

# ==============================
# vLLM ecosystem
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm transformers sentencepiece "huggingface_hub[cli]" hf_transfer einops

# Flash acceleration (optional)
RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      python -m pip install --no-cache-dir flash-attn || true; \
    fi

RUN if [[ "${INSTALL_FLASHINFER}" = "true" ]]; then \
      python -m pip install --no-cache-dir flashinfer || true; \
    fi

# ==============================
# Download model at build time (using HF_TOKEN)
# ==============================
RUN set -euo pipefail && \
    mkdir -p "${HF_HOME}" && \
    MODEL_DIR="${HF_HOME}/${HF_MODEL_ID}" && \
    echo "[build] HF_HOME=${HF_HOME}" && \
    echo "[build] HF_MODEL_ID=${HF_MODEL_ID}" && \
    echo "[build] MODEL_DIR=${MODEL_DIR}" && \
    \
    # 1) Require non-empty HF_TOKEN
    if [[ -z "${HF_TOKEN:-}" ]]; then \
      echo "[build] ERROR: HF_TOKEN is empty." >&2; \
      echo "[build] Please pass HF_TOKEN via buildx bake, e.g.:" >&2; \
      echo "[build]   HF_TOKEN=hf_xxx docker buildx bake vllm-qwen --no-cache --push" >&2; \
      exit 2; \
    fi && \
    \
    # 2) Download model (must succeed)
    echo "[build] Downloading model at build time..." && \
    huggingface-cli download \
      "${HF_MODEL_ID}" \
      --local-dir "${MODEL_DIR}" \
      --local-dir-use-symlinks False \
      --resume-download \
      --token "${HF_TOKEN}" && \
    \
    # 3) Verify model directory after download
    if [[ ! -d "${MODEL_DIR}" ]]; then \
      echo "[build] ERROR: MODEL_DIR ${MODEL_DIR} does not exist after download" >&2; \
      exit 3; \
    fi && \
    if [[ -z "$(ls -A "${MODEL_DIR}")" ]]; then \
      echo "[build] ERROR: MODEL_DIR ${MODEL_DIR} is empty after download" >&2; \
      exit 4; \
    fi && \
    echo "[build] Model download completed: ${MODEL_DIR}"

# ==============================
# Install pnpm globally
# ==============================
RUN npm install -g pnpm && \
    pnpm --version

# ==============================
# Install MoltBot (OpenClaw) for ubuntu user
# ==============================
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

RUN mkdir -p /home/${UBUNTU_USER}/.local/bin && \
    curl -fsSL https://molt.bot/install.sh | bash -s -- --install-method git && \
    echo 'export PATH=$HOME/.local/bin:$PATH' >> /home/${UBUNTU_USER}/.bashrc && \
    /home/${UBUNTU_USER}/.local/bin/openclaw --version || true

# ==============================
# Create OpenClaw configuration
# ==============================
RUN mkdir -p /home/${UBUNTU_USER}/.openclaw /home/${UBUNTU_USER}/clawd && \
    cat > /home/${UBUNTU_USER}/.openclaw/openclaw.json <<'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.1.30",
    "lastTouchedAt": "2026-02-01T17:15:00.000Z"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "vllm-yotta": {
        "baseUrl": "http://localhost:8001/v1",
        "apiKey": "dummy-key",
        "api": "openai-responses",
        "models": [
          {
            "id": "/workspace/hf/Qwen/Qwen3-30B-A3B-Instruct-2507",
            "name": "Qwen3-30B-A3B-Instruct-2507",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 32768,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "vllm-yotta//workspace/hf/Qwen/Qwen3-30B-A3B-Instruct-2507"
      },
      "models": {
        "vllm-yotta//workspace/hf/Qwen/Qwen3-30B-A3B-Instruct-2507": {
          "alias": "Qwen3"
        }
      },
      "workspace": "/home/ubuntu/clawd",
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "gateway": {
    "auth": {
      "token": "clawdbot"
    },
    "mode": "local"
  }
}
EOF

# Switch back to root to complete remaining build steps
USER root
WORKDIR /

# ==============================
# Copy platform start.sh (from bake context)
# ==============================
COPY --from=scripts start.sh /start_platform.sh
RUN chmod +x /start_platform.sh

# Copy branding
COPY --from=logo yotta.txt /etc/yotta.txt

# ==============================
# post_start.sh: start vLLM + OpenClaw Gateway
# ==============================
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Prevent concurrent startups (critical on platforms)
# ------------------------------
mkdir -p /workspace
exec 9>/workspace/vllm_start.lock
flock -n 9 || { echo "[post_start] Another startup in progress, exit"; exit 0; }

LOG="${VLLM_LOG:-/workspace/vllm.log}"
OPENCLAW_LOG="${OPENCLAW_LOG:-/workspace/openclaw.log}"
mkdir -p /workspace "${HF_HOME}"

MODEL_DIR="${HF_HOME}/${HF_MODEL_ID}"

echo "[post_start] HF_HOME=${HF_HOME}"
echo "[post_start] HF_MODEL_ID=${HF_MODEL_ID}"
echo "[post_start] VLLM_MODEL=${VLLM_MODEL}"
echo "[post_start] VLLM_HOST=${VLLM_HOST}"
echo "[post_start] VLLM_PORT=${VLLM_PORT}"
echo "[post_start] TP_SIZE=${TP_SIZE} MAX_MODEL_LEN=${MAX_MODEL_LEN} GPU_MEM_UTIL=${GPU_MEM_UTIL}"
echo "[post_start] VLLM_EXTRA_ARGS=${VLLM_EXTRA_ARGS}"
echo "[post_start] MODEL_DIR=${MODEL_DIR}"
echo "[post_start] OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT}"
echo "[post_start] OPENCLAW_AUTH_TOKEN=${OPENCLAW_AUTH_TOKEN}"

# ------------------------------
# Build-time model presence check
# ------------------------------
if [[ ! -d "${MODEL_DIR}" ]]; then
  echo "[post_start] ERROR: Model dir ${MODEL_DIR} not found."
  echo "[post_start] You must build the image with model pre-downloaded."
  exit 1
fi

required=(
  "${MODEL_DIR}/config.json"
  "${MODEL_DIR}/tokenizer.json"
  "${MODEL_DIR}/tokenizer_config.json"
)

missing=0
for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "[post_start] Missing required file: $f"
    missing=1
  fi
done

if [[ "${missing}" -eq 1 ]]; then
  echo "[post_start] ERROR: Model directory is incomplete. Please rebuild image with a clean model download."
  exit 1
fi

# ------------------------------
# Ensure single vLLM instance
# ------------------------------
pkill -f "vllm.entrypoints.openai.api_server" || true
sleep 1

# ------------------------------
# Port conflict handling (HTTP port)
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

# ------------------------------
# Wait for vLLM to be ready (health check)
# ------------------------------
echo "[post_start] Waiting for vLLM to be ready..."
MAX_WAIT=180
ELAPSED=0
while ! curl -s http://localhost:${VLLM_PORT}/health >/dev/null 2>&1; do
  if [ ${ELAPSED} -ge ${MAX_WAIT} ]; then
    echo "[post_start] ERROR: vLLM failed to start within ${MAX_WAIT}s"
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done
echo "[post_start] vLLM is ready (took ${ELAPSED}s)"

# ------------------------------
# Update OpenClaw config with runtime token
# ------------------------------
if [[ -n "${OPENCLAW_AUTH_TOKEN}" && "${OPENCLAW_AUTH_TOKEN}" != "clawdbot" ]]; then
  echo "[post_start] Updating OpenClaw auth token in config..."
  if command -v jq >/dev/null 2>&1; then
    jq --arg token "${OPENCLAW_AUTH_TOKEN}" \
       '.gateway.auth.token = $token' \
       /home/ubuntu/.openclaw/openclaw.json > /tmp/openclaw.json.tmp && \
    mv /tmp/openclaw.json.tmp /home/ubuntu/.openclaw/openclaw.json
  else
    echo "[post_start] WARNING: jq not found, cannot update token dynamically"
  fi
fi

# ------------------------------
# Start OpenClaw Gateway
# ------------------------------
pkill -f "openclaw gateway" || true
sleep 1

if lsof -i :"${OPENCLAW_GATEWAY_PORT}" >/dev/null 2>&1; then
  echo "[post_start] WARNING: Port ${OPENCLAW_GATEWAY_PORT} already in use"
  lsof -i :"${OPENCLAW_GATEWAY_PORT}" || true
fi

export PATH="/home/ubuntu/.local/bin:$PATH"

echo "[post_start] Starting OpenClaw gateway on port ${OPENCLAW_GATEWAY_PORT}..."

nohup /home/ubuntu/.local/bin/openclaw gateway >> "${OPENCLAW_LOG}" 2>&1 &

echo "[post_start] OpenClaw gateway launched. Log: ${OPENCLAW_LOG}"
echo "[post_start] Access gateway at http://localhost:${OPENCLAW_GATEWAY_PORT}"
echo "[post_start] Use auth token: ${OPENCLAW_AUTH_TOKEN}"

# ------------------------------
# Summary
# ------------------------------
echo ""
echo "========================================"
echo "✓ vLLM API: http://localhost:${VLLM_PORT}"
echo "✓ OpenClaw Gateway: http://localhost:${OPENCLAW_GATEWAY_PORT}"
echo "✓ Auth Token: ${OPENCLAW_AUTH_TOKEN}"
echo "========================================"
echo ""
EOF

# ==============================
# start wrapper: platform start + post_start
# ==============================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Run platform native startup first (SSH/Nginx/user injection, etc.)
/start_platform.sh &

# Give platform services a brief startup window
sleep 1

# Then start vLLM (check & start only, no model download)
/post_start.sh

# Keep container in foreground
wait -n
EOF

# ==============================
# Permissions & bashrc banner
# ==============================
RUN chmod +x /post_start.sh /start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc && \
    echo 'export PATH=$HOME/.local/bin:$PATH' >> /root/.bashrc

# ==============================
# Install jq for config updates
# ==============================
RUN apt-get update && \
    apt-get install -y jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ==============================
# Ports & Entrypoint
# ==============================
EXPOSE 22 8001 18789

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]

