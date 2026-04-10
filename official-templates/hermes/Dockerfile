# ==============================
# Global Args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG HERMES_MODEL="NousResearch/Hermes-3-Llama-3.1-8B"

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
    TORCH_CUDA_ARCH_LIST="12.0" \
    CMAKE_CUDA_ARCHITECTURES="120" \
    PYTORCH_ALLOC_CONF="expandable_segments:True" \
    PYTHON_VERSION="3.11" \
    JUPYTER_PASSWORD=yotta \
    \
    # HuggingFace
    HF_HOME=/workspace/.cache/huggingface \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    \
    # vLLM runtime defaults
    HERMES_MODEL="NousResearch/Hermes-3-Llama-3.1-8B" \
    VLLM_HOST="0.0.0.0" \
    VLLM_PORT="8000" \
    VLLM_SERVED_MODEL_NAME="hermes" \
    VLLM_MAX_MODEL_LEN="32768" \
    VLLM_GPU_MEMORY_UTILIZATION="0.90" \
    VLLM_TRUST_REMOTE_CODE="true" \
    VLLM_EXTRA_ARGS="--enable-prefix-caching --enable-auto-tool-choice --tool-call-parser hermes --no-enable-log-requests" \
    VLLM_LOG="/workspace/vllm.log" \
    OPENAI_BASE_URL=http://localhost:8000/v1

RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ==============================
# System packages
# ==============================
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

# root SSH directory
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# ==============================
# SSH config
# ==============================
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config

# ==============================
# Python / pip (deadsnakes PPA — same as OpenClaw)
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
# PyTorch (nightly cu128 — supports Blackwell sm_120)
# ==============================
RUN python -m pip install --no-cache-dir --pre \
    --index-url https://download.pytorch.org/whl/nightly/cu128 \
    --extra-index-url https://pypi.org/simple \
    --extra-index-url https://pypi.nvidia.com \
    torch torchvision torchaudio

# ==============================
# vLLM ecosystem (latest stable — same pattern as OpenClaw)
# ==============================
RUN python -m pip install --no-cache-dir \
      vllm transformers sentencepiece "huggingface_hub[cli]" hf_transfer einops \
      openai httpx accelerate

# ==============================
# Jupyter + common tools
# ==============================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 datasets

RUN python -c "import jupyter; import notebook; import jupyterlab; print('jupyter ok')"

# ==============================
# JupyterLab config
# ==============================
RUN mkdir -p /root/.jupyter && printf '%s\n' \
    'c.ServerApp.token = "yotta"' \
    'c.ServerApp.password = ""' \
    'c.ServerApp.allow_remote_access = True' \
    'c.ServerApp.allow_origin = "*"' \
    'c.NotebookApp.token = "yotta"' \
    'c.NotebookApp.password = ""' \
    'c.NotebookApp.allow_remote_access = True' \
    > /root/.jupyter/jupyter_lab_config.py && \
    chmod 600 /root/.jupyter/jupyter_lab_config.py

# ==============================
# hermes-agent CLI
# ==============================
ENV HERMES_HOME=/root/.hermes

RUN set -eux; \
    git clone --depth 1 https://github.com/NousResearch/hermes-agent.git /tmp/hermes-agent; \
    cd /tmp/hermes-agent; \
    pip install --no-cache-dir . ; \
    mkdir -p "$HERMES_HOME"; \
    chmod 777 "$HERMES_HOME"; \
    rm -rf /tmp/hermes-agent

# Build-time assertion: hermes CLI present
RUN set -eux; \
    which hermes; \
    test -f /usr/local/bin/hermes; \
    hermes --help | head -3; \
    echo "[OK] hermes installed at $(which hermes)"

# ==============================
# start.sh — entrypoint script (inline)
# ==============================
RUN cat > /start.sh <<'STARTEOF'
#!/bin/bash
set -e

start_nginx() {
    echo "Starting Nginx service..."
    service nginx start
}

execute_script() {
    local script_path=$1
    local script_msg=$2
    if [ -f "${script_path}" ]; then
        echo "${script_msg}"
        bash ${script_path}
    fi
}

setup_ssh() {
    if [ "$PUBLIC_KEY" ]; then
        echo "Setting up SSH..."
        mkdir -p ~/.ssh
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    fi
    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -q -N ''
        echo "RSA key fingerprint:"
        ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub
    fi
    if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
        ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -q -N ''
        echo "DSA key fingerprint:"
        ssh-keygen -lf /etc/ssh/ssh_host_dsa_key.pub
    fi
    if [ ! -f /etc/ssh/ssh_host_ecdsa_key ]; then
        ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -q -N ''
        echo "ECDSA key fingerprint:"
        ssh-keygen -lf /etc/ssh/ssh_host_ecdsa_key.pub
    fi
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -q -N ''
        echo "ED25519 key fingerprint:"
        ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
    fi
    service ssh start
    echo "SSH host keys:"
    for key in /etc/ssh/*.pub; do
        echo "Key: $key"
        ssh-keygen -lf $key
    done
}

export_env_vars() {
    echo "Exporting environment variables..."
    printenv | grep -E '^YOTTA_|^PATH=|^_=' | awk -F = '{ print "export " $1 "=\"" $2 "\"" }' >> /etc/rp_environment
    echo 'export PATH=/usr/local/nvidia/bin:/usr/local/cuda-12.8/bin:~/.local/bin:$PATH' >> /etc/rp_environment
    echo 'source /etc/rp_environment' >> ~/.bashrc
}

start_jupyter() {
    if [ "$JUPYTER_PASSWORD" ]; then
        echo "Starting Jupyter Lab..."
        mkdir -p /workspace && \
        cd / && \
        nohup python3 -m jupyter lab --allow-root --no-browser --port=8888 --ip=* \
          --FileContentsManager.delete_to_trash=False \
          --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
          --ServerApp.token=$JUPYTER_PASSWORD \
          --ServerApp.allow_origin=* \
          --ServerApp.preferred_dir=/workspace &> /workspace/jupyter.log &
        echo "Jupyter Lab started"
    fi
}

configure_hermes() {
    echo "Configuring hermes-agent..."
    local dirs=("/root/.hermes")
    # Detect non-root user (Yotta platform runs as 'user')
    if id user &>/dev/null; then
        dirs+=("$(eval echo ~user)/.hermes")
    fi
    for dir in "${dirs[@]}"; do
        mkdir -p "${dir}"
        cat > "${dir}/config.yaml" << CFGEOF
model:
  default: "${VLLM_SERVED_MODEL_NAME:-hermes}"
  provider: custom
  base_url: "http://localhost:${VLLM_PORT:-8000}/v1"
  api_key: "EMPTY"
  context_length: ${VLLM_MAX_MODEL_LEN:-8192}

terminal:
  backend: local

approvals:
  mode: "off"
CFGEOF
        cat > "${dir}/.env" << ENVEOF
OPENAI_API_KEY=EMPTY
ENVEOF
        chmod -R 777 "${dir}"
        echo "  -> ${dir}/config.yaml"
    done
    # Fix ownership for non-root user
    if id user &>/dev/null; then
        chown -R user:user "$(eval echo ~user)/.hermes" 2>/dev/null || true
    fi
}

start_nginx
execute_script "/pre_start.sh" "Running pre-start script..."
echo "Pod Started"
setup_ssh
start_jupyter
export_env_vars
configure_hermes
execute_script "/post_start.sh" "Running post-start script..."
echo "Start script(s) finished, pod is ready to use."
sleep infinity
STARTEOF
RUN chmod 755 /start.sh

# ==============================
# post_start.sh: launch vLLM + configure hermes-agent
# ==============================
RUN cat > /post_start.sh <<'POSTEOF'
#!/usr/bin/env bash
set -euo pipefail

LOG="${VLLM_LOG:-/workspace/vllm.log}"

echo "[hermes] Starting vLLM inference server..."
echo "[hermes]   Model: ${HERMES_MODEL}"
echo "[hermes]   Host:  ${VLLM_HOST}:${VLLM_PORT}"
echo "[hermes]   Extra: ${VLLM_EXTRA_ARGS:-}"

# --- Part 1: Launch vLLM (same pattern as OpenClaw) ---

pkill -f "vllm.entrypoints.openai.api_server" || true
sleep 1

if lsof -i :"${VLLM_PORT}" >/dev/null 2>&1; then
    echo "[hermes] ERROR: Port ${VLLM_PORT} already in use."
    lsof -i :"${VLLM_PORT}" || true
    exit 1
fi

TRUST_FLAG=""
if [ "${VLLM_TRUST_REMOTE_CODE:-true}" = "true" ]; then
    TRUST_FLAG="--trust-remote-code"
fi

nohup python -m vllm.entrypoints.openai.api_server \
    --model "${HERMES_MODEL}" \
    --served-model-name "${VLLM_SERVED_MODEL_NAME}" \
    --host "${VLLM_HOST}" \
    --port "${VLLM_PORT}" \
    --max-model-len "${VLLM_MAX_MODEL_LEN}" \
    --gpu-memory-utilization "${VLLM_GPU_MEMORY_UTILIZATION}" \
    ${TRUST_FLAG} \
    ${VLLM_EXTRA_ARGS} \
    >> "${LOG}" 2>&1 &

echo "[hermes] vLLM launched in background. Log: ${LOG}"

# --- Part 2: Wait for vLLM to be ready ---

VLLM_STARTUP_TIMEOUT="${VLLM_STARTUP_TIMEOUT:-600}"
ELAPSED=0
echo "[hermes] Waiting for vLLM to be ready (max ${VLLM_STARTUP_TIMEOUT}s)..."
while ! curl -s "http://localhost:${VLLM_PORT}/health" >/dev/null 2>&1; do
    if [ ${ELAPSED} -ge ${VLLM_STARTUP_TIMEOUT} ]; then
        echo "[hermes] ERROR: vLLM failed to start within ${VLLM_STARTUP_TIMEOUT}s"
        tail -100 "${LOG}"
        exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo "[hermes] Still waiting... (${ELAPSED}/${VLLM_STARTUP_TIMEOUT}s)"
    fi
done
echo "[hermes] vLLM is ready (took ${ELAPSED}s)"

echo ""
echo "========================================"
echo "  vLLM API:  http://localhost:${VLLM_PORT}"
echo "  Model:     ${VLLM_SERVED_MODEL_NAME}"
echo "  Provider:  custom (OpenAI-compatible)"
echo "  hermes:    $(which hermes)"
echo "========================================"
echo ""
POSTEOF
RUN chmod 755 /post_start.sh

# ==============================
# Permissions & bashrc
# ==============================
RUN echo 'export PATH=$HOME/.local/bin:$PATH' >> /root/.bashrc

# ==============================
# Ports & Entrypoint
# ==============================
EXPOSE 22 80 8000 8888

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]
