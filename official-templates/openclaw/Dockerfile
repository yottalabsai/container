# ==============================
# Global Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="user"
ARG INSTALL_FLASHATTN="false"
ARG INSTALL_FLASHINFER="false"
ARG HF_MODEL_ID="Qwen/Qwen3-30B-A3B-Instruct-2507"
ARG HF_TOKEN

# ==============================
# Build Stages
# ==============================
FROM scratch AS logo
COPY yotta.txt yotta.txt

FROM scratch AS scripts
COPY start.sh start.sh

# ==============================
# Base Image
# ==============================
FROM ${BASE_IMAGE}

WORKDIR /

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
      PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120" \
    PYTORCH_ALLOC_CONF="expandable_segments:True" \
    PYTHON_VERSION="3.11" \
    UBUNTU_USER="user" \
    HF_MODEL_ID="Qwen/Qwen3-30B-A3B-Instruct-2507" \
    \
    # vLLM runtime defaults
    VLLM_MODEL="Qwen/Qwen3-30B-A3B-Instruct-2507" \
    VLLM_HOST="0.0.0.0" \
    VLLM_PORT="8001" \
    TP_SIZE="4" \
    MAX_MODEL_LEN="32768" \
    GPU_MEM_UTIL="0.75" \
    MAX_NUM_SEQS="128" \
    VLLM_TRUST_REMOTE_CODE="true" \
    VLLM_EXTRA_ARGS="--enable-prefix-caching --enable-auto-tool-choice --tool-call-parser hermes" \
    VLLM_LOG="/workspace/vllm.log" \
    \
    # OpenClaw defaults
    OPENCLAW_GATEWAY_PORT="18789" \
    OPENCLAW_AUTH_TOKEN="clawdbot" \
    OPENCLAW_LOG="/workspace/openclaw.log"

RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"   
#=======================================================
# System packages installation
#======================================================
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx \
      openssh-server openssh-client \
      tmux vim zsh zip unzip less procps net-tools htop \
      tini sudo lsof gnupg2; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    update-locale; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "Etc/UTC" > /etc/timezone; \
    dpkg-reconfigure -f noninteractive tzdata; \
    mkdir -p /var/run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# root SSH 目录（给平台注入 key 用）
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# ==============================
# SSH config (no user creation - let platform handle it)
# ==============================
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config

# ==============================
# Python / pip
# ==============================
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv"; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3; \
    which python && python --version; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \  
    python /tmp/get-pip.py; \
    rm -f /tmp/get-pip.py; \
    python -m pip install --no-cache-dir -U pip setuptools wheel; \        
    python -m pip --version

# ==============================
# PyTorch (nightly cu128)
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu128 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

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
# vLLM ecosystem
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm transformers sentencepiece "huggingface_hub[cli]" hf_transfer einops


RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      python -m pip install --no-cache-dir flash-attn || true; \
    fi

RUN if [[ "${INSTALL_FLASHINFER}" = "true" ]]; then \
      python -m pip install --no-cache-dir flashinfer || true; \
    fi

# ==============================
# 构建阶段下载模型（使用 HF_TOKEN）
# ==============================
ARG HF_TOKEN
RUN set -euo pipefail && \
    mkdir -p "${HF_HOME}" && \
    MODEL_DIR="${HF_HOME}/${HF_MODEL_ID}" && \
    echo "[build] HF_HOME=${HF_HOME}" && \
    echo "[build] HF_MODEL_ID=${HF_MODEL_ID}" && \
    echo "[build] MODEL_DIR=${MODEL_DIR}" && \
    \
    # 1) 强制要求 HF_TOKEN 非空
    if [[ -z "${HF_TOKEN:-}" ]]; then \
      echo "[build] ERROR: HF_TOKEN is empty." >&2; \
      echo "[build] Please pass HF_TOKEN via buildx bake, e.g.:" >&2; \    
      echo "[build]   HF_TOKEN=hf_xxx docker buildx bake vllm-qwen --no-cache --push" >&2; \
      exit 2; \
    fi && \
    \
    # 2) 下载模型（必须成功）
    echo "[build] Downloading model at build time..." && \
    huggingface-cli download \
      "${HF_MODEL_ID}" \
      --local-dir "${MODEL_DIR}" \
      --local-dir-use-symlinks False \
      --resume-download \
      --token "${HF_TOKEN}" && \
    \
    # 3) 下载完成后检查目录
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
# Install OpenClaw globally (build-time installation)
# ==============================
RUN echo "[build] Installing OpenClaw globally..." && \
    npm install -g openclaw@latest && \
    openclaw --version && \
    which openclaw && \
    echo "[build] OpenClaw installed successfully"

# ==============================
# Ensure openclaw is accessible for all users (including root and platform-created users)
# ==============================
RUN echo 'export PATH="/usr/local/bin:$PATH"' > /etc/profile.d/openclaw-path.sh && \
    chmod 644 /etc/profile.d/openclaw-path.sh && \
    echo 'export PATH="/usr/local/bin:$PATH"' >> /etc/bash.bashrc && \
    echo "[build] OpenClaw PATH configuration added for all users"

# ==============================
# Copy from build stages
# ==============================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc || true

# ==============================
# post_start.sh: 启动 vLLM(root) + OpenClaw(user)
# ==============================
RUN cat >/post_start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# ------------------------------
# Prevent concurrent startups
# ------------------------------
mkdir -p /workspace
exec 9>/workspace/vllm_start.lock
flock -n 9 || { echo "[post_start] Another startup in progress, exit"; exit 0; }

LOG="${VLLM_LOG:-/workspace/vllm.log}"
OPENCLAW_LOG="${OPENCLAW_LOG:-/workspace/openclaw.log}"
HF_HOME="${HF_HOME:-/workspace/hf}"
HF_MODEL_ID="${HF_MODEL_ID:-Qwen/Qwen3-30B-A3B-Instruct-2507}"
mkdir -p /workspace "${HF_HOME}"

MODEL_DIR="${HF_HOME}/${HF_MODEL_ID}"

echo "[post_start] HF_HOME=${HF_HOME}"
echo "[post_start] HF_MODEL_ID=${HF_MODEL_ID}"
echo "[post_start] VLLM_MODEL=${VLLM_MODEL:-Qwen/Qwen3-30B-A3B-Instruct-2507}"
echo "[post_start] VLLM_HOST=${VLLM_HOST:-0.0.0.0}"
echo "[post_start] VLLM_PORT=${VLLM_PORT:-8001}"
echo "[post_start] TP_SIZE=${TP_SIZE:-4} MAX_MODEL_LEN=${MAX_MODEL_LEN:-32768} GPU_MEM_UTIL=${GPU_MEM_UTIL:-0.75}"
echo "[post_start] MAX_NUM_SEQS=${MAX_NUM_SEQS:-128}"
echo "[post_start] VLLM_EXTRA_ARGS=${VLLM_EXTRA_ARGS:-}"
echo "[post_start] MODEL_DIR=${MODEL_DIR}"
echo "[post_start] OPENCLAW_GATEWAY_PORT=${OPENCLAW_GATEWAY_PORT:-18789}"  
echo "[post_start] OPENCLAW_AUTH_TOKEN=${OPENCLAW_AUTH_TOKEN:-clawdbot}"   

# ------------------------------
# Ensure user exists (platform should create, but double check)
# ------------------------------
if ! id user &>/dev/null; then
  echo "[post_start] Creating user 'user'..."
  useradd -m -s /bin/bash user
  echo "user:user" | chpasswd
fi

# Fix permissions for user directories
echo "[post_start] Setting up permissions..."
mkdir -p /home/user /workspace/openclaw-workspace
chown -R user:user /home/user
chown -R user:user /workspace/openclaw-workspace
chmod 755 /home/user /workspace/openclaw-workspace

# ------------------------------
# Part 1: vLLM Startup (as root - requires GPU access)
# ------------------------------

# Build-time model presence check
if [[ ! -d "${MODEL_DIR}" ]]; then
  echo "[post_start] ERROR: Model dir ${MODEL_DIR} not found."
  echo "[post_start] You must build the image with model pre-downloaded."  
  exit 1
fi

required_files="${MODEL_DIR}/config.json ${MODEL_DIR}/tokenizer.json ${MODEL_DIR}/tokenizer_config.json"

missing=0
for f in ${required_files}; do
  if [[ ! -f "$f" ]]; then
    echo "[post_start] Missing required file: $f"
    missing=1
  fi
done

if [[ "${missing}" -eq 1 ]]; then
  echo "[post_start] ERROR: Model directory is incomplete. Please rebuild image with a clean model download."
  exit 1
fi

# Ensure single vLLM instance
pkill -f "vllm.entrypoints.openai.api_server" || true
sleep 1

# Port conflict handling
if lsof -i :"${VLLM_PORT}" >/dev/null 2>&1; then
  echo "[post_start] ERROR: Port ${VLLM_PORT} already in use."
  lsof -i :"${VLLM_PORT}" || true
  exit 1
fi

# Start vLLM (OpenAI compatible server)
TRUST_FLAG=""
if [ "${VLLM_TRUST_REMOTE_CODE:-true}" = "true" ]; then
  TRUST_FLAG="--trust-remote-code"
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
  --max-num-seqs "${MAX_NUM_SEQS:-128}" \
  ${TRUST_FLAG} \
  ${VLLM_EXTRA_ARGS} \
  >> "${LOG}" 2>&1 &

echo "[post_start] vLLM launched. Log: ${LOG}"

# Wait for vLLM to be ready
echo "[post_start] Waiting for vLLM to be ready (max 600s)..."
VLLM_STARTUP_TIMEOUT="${VLLM_STARTUP_TIMEOUT:-600}"
ELAPSED=0
while ! curl -s http://localhost:${VLLM_PORT}/health >/dev/null 2>&1; do   
  if [ ${ELAPSED} -ge ${VLLM_STARTUP_TIMEOUT} ]; then
    echo "[post_start] ERROR: vLLM failed to start within ${VLLM_STARTUP_TIMEOUT}s"
    tail -100 "${LOG}"
    exit 1
  fi
  sleep 3
  ELAPSED=$((ELAPSED + 3))
  if [ $((ELAPSED % 30)) -eq 0 ]; then
    echo "[post_start] Still waiting... (${ELAPSED}/${VLLM_STARTUP_TIMEOUT}s)"
  fi
done
echo "[post_start] vLLM is ready (took ${ELAPSED}s)"

# ------------------------------
# Part 2: OpenClaw Setup (as user - configuration only)
# ------------------------------
echo "[post_start] Configuring OpenClaw for user 'user'..."

su - user <<'OPENCLAW_SETUP'
set -euo pipefail

# Environment variables
export OPENCLAW_LOG="${OPENCLAW_LOG:-/workspace/openclaw.log}"
export OPENCLAW_GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
export OPENCLAW_AUTH_TOKEN="${OPENCLAW_AUTH_TOKEN:-clawdbot}"

echo "[openclaw] User: $(whoami), Home: $HOME"
echo "[openclaw] OpenClaw version: $(openclaw --version)"

# Ensure workspace directories with proper permissions
mkdir -p ~/.openclaw /workspace/openclaw-workspace
chmod 755 ~/.openclaw /workspace/openclaw-workspace

# Initialize OpenClaw configuration directory
if [ ! -f ~/.openclaw/openclaw.json ]; then
  echo "[openclaw] Initializing configuration..."
  yes "" | openclaw setup 2>&1 | head -50 || echo "[openclaw] Setup completed with defaults"
  sleep 2
fi

# Overwrite with custom vLLM configuration
echo "[openclaw] Configuring for local vLLM..."
cat > ~/.openclaw/openclaw.json <<'OPENCLAW_CONFIG'
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
      "workspace": "/workspace/openclaw-workspace",
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
  "skills": {
    "web_search": {
      "enabled": true,
      "provider": "built-in"
    }
  },
  "gateway": {
    "auth": {
      "token": "clawdbot"
    },
    "mode": "local"
  }
}
OPENCLAW_CONFIG

echo "[openclaw] Configuration updated"

# Ensure token is set via config command (overrides any auto-generated token)
openclaw config set gateway.auth.token "${OPENCLAW_AUTH_TOKEN}"
echo "[openclaw] Auth token configured: ${OPENCLAW_AUTH_TOKEN}"

# Stop any existing gateway instances before starting
echo "[openclaw] Checking for existing gateway processes..."
if pgrep -f "openclaw gateway" >/dev/null 2>&1; then
  echo "[openclaw] Stopping existing gateway..."
  openclaw gateway stop || true
  sleep 2
  pkill -f "openclaw gateway" || true
  sleep 1
fi

# Start OpenClaw Gateway (globally installed, directly callable)
echo "[openclaw] Starting gateway on port ${OPENCLAW_GATEWAY_PORT}..."     

nohup openclaw gateway >> "${OPENCLAW_LOG}" 2>&1 &

# Wait for Gateway to start
sleep 4

# Check if Gateway is ready
OPENCLAW_READY=0
for i in {1..30}; do
  if curl -s http://localhost:${OPENCLAW_GATEWAY_PORT}/ >/dev/null 2>&1 || \
     netstat -tuln 2>/dev/null | grep -q ":${OPENCLAW_GATEWAY_PORT}"; then 
    echo "[openclaw] ✓ Gateway is ready"
    OPENCLAW_READY=1
    break
  fi
  sleep 1
done

if [[ ${OPENCLAW_READY} -eq 0 ]]; then
  echo "[openclaw] WARNING: Gateway may not be responding. Check logs:"    
  tail -30 "${OPENCLAW_LOG}" || echo "(log file not found)"
else
  echo "[openclaw] Gateway launched. Log: ${OPENCLAW_LOG}"
fi

echo "[openclaw] Access gateway at http://localhost:${OPENCLAW_GATEWAY_PORT}"
echo "[openclaw] Auth token: ${OPENCLAW_AUTH_TOKEN}"

OPENCLAW_SETUP

# ------------------------------
# Summary
# ------------------------------
echo ""
echo "========================================"
echo "✓ vLLM API: http://localhost:${VLLM_PORT}"
echo "✓ OpenClaw Gateway: http://localhost:${OPENCLAW_GATEWAY_PORT}"       
echo "✓ Auth Token: ${OPENCLAW_AUTH_TOKEN}"
echo "✓ OpenClaw user: user"
echo "✓ OpenClaw path: $(which openclaw)"
echo "✓ OpenClaw version: $(openclaw --version)"
echo "========================================"
echo ""
EOF



# ==============================
# Permissions & bashrc banner
# ==============================
RUN chmod +x /post_start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc && \
    echo 'export PATH=$HOME/.local/bin:$PATH' >> /root/.bashrc

# Note: User .bashrc is configured at runtime by post_start.sh

# ==============================
# Ports & Entrypoint
# ==============================
EXPOSE 22 8001 18789

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]
