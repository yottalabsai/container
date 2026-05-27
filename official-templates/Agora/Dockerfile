# =========================================================
# Yotta x Agora (Pluralis-8B) Node Image
# =========================================================
# Base: CUDA 12.8 + cuDNN — matches Agora's PyTorch cu128 wheel
# Python: 3.11 (Agora hard requirement, built from source)
# Entry: platform start.sh → /post_start.sh (inlined below)
# =========================================================

FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG JUPYTER_PASSWORD=yotta
ARG PYTHON_VERSION="3.11.9"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH=/usr/local/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=${JUPYTER_PASSWORD}

WORKDIR /workspace

# =========================================================
# System packages
# =========================================================
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs locales tzdata \
      build-essential pkg-config ninja-build cmake \
      ffmpeg libgl1 libglib2.0-0 \
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof sudo \
      iproute2 iputils-ping dnsutils \
      nginx openssh-server openssh-client \
      libnccl2 libnccl-dev \
      software-properties-common \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    mkdir -p /var/run/sshd /var/log/supervisor; \
    chmod 700 /var/run/sshd /var/log/supervisor; \
    chmod 755 /var/log; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Python 3.11 — built from source (Agora hard requirement)
# =========================================================
RUN set -eux; \
    curl -fSL --retry 5 \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
      -o /tmp/Python.tgz; \
    mkdir -p /tmp/python-src; \
    tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1; \
    rm -f /tmp/Python.tgz; \
    cd /tmp/python-src; \
    ./configure --with-ensurepip=install; \
    make -j"$(nproc)"; \
    make altinstall; \
    cd /; \
    rm -rf /tmp/python-src; \
    ln -sf /usr/local/bin/python3.11 /usr/bin/python3; \
    ln -sf /usr/local/bin/python3.11 /usr/bin/python; \
    python -m pip install --no-cache-dir --upgrade "pip>=25.3"

# =========================================================
# PyTorch 2.7.0 + cu128  (Agora requirement)
# =========================================================
RUN pip install --no-cache-dir \
      torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0 \
      --index-url https://download.pytorch.org/whl/cu128

# =========================================================
# Clone Agora and install dependencies
# =========================================================
RUN set -eux; \
    git clone --depth 1 https://github.com/PluralisResearch/agora /workspace/agora; \
    cd /workspace/agora; \
    pip install --no-cache-dir \
      --build-constraint constraints.txt \
      -e ./agora_server \
      -e ./agora; \
    mkdir -p /workspace/agora/logs

# =========================================================
# Jupyter + monitoring tools
# =========================================================
RUN pip install --no-cache-dir \
      jupyterlab ipywidgets notebook tensorboard wandb

# =========================================================
# SSH hardening
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# =========================================================
# nginx + README
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# post_start.sh — inlined
#
# Called by the platform's start.sh after SSH + Jupyter are up.
# Launches one Agora node per GPU listed in AGORA_GPU_IDS.
#
# Required env vars (set in RunPod / Vast.ai template):
#   AGORA_HF_TOKEN      HuggingFace read token (hf_...)
#
# Optional env vars:
#   AGORA_EMAIL         Email for leaderboard (default: empty)
#   AGORA_GPU_IDS       Comma-separated GPU IDs (default: "0")
#   AGORA_ANNOUNCE_PORT External port assigned by platform for GPU 0.
#                       Subsequent GPUs use AGORA_ANNOUNCE_PORT+N.
#                       If unset, host_port == announce_port (AWS/GCP/Lambda).
# =========================================================
RUN cat > /post_start.sh << 'EOF'
#!/bin/bash
set -e

AGORA_DIR=/workspace/agora
PYTHON=/usr/local/bin/python3.11
LOG_DIR=${AGORA_DIR}/logs
mkdir -p "$LOG_DIR"

# ── Validate ──────────────────────────────────────────────
if [ -z "$AGORA_HF_TOKEN" ]; then
    echo "[Agora] AGORA_HF_TOKEN not set — skipping Agora launch."
    echo "[Agora] Set AGORA_HF_TOKEN and restart to participate."
    exit 0
fi

# ── GPU list ──────────────────────────────────────────────
GPU_IDS="${AGORA_GPU_IDS:-0}"
IFS=',' read -ra GPUS <<< "$GPU_IDS"

# ── Public IP ─────────────────────────────────────────────
PUBLIC_IP=$(curl -s --retry 5 --retry-delay 2 https://api.ipify.org || true)
echo "[Agora] Public IP: ${PUBLIC_IP:-unknown}"

# ── run.json ──────────────────────────────────────────────
RUN_JSON="${AGORA_DIR}/run.json"
if [ ! -f "$RUN_JSON" ]; then
    echo "[Agora] ERROR: run.json not found at ${RUN_JSON}."
    exit 1
fi

RUN_CONFIG=$(jq -r '.run_config' "$RUN_JSON")
AUTH_SERVER=$(jq -r '.auth_server' "$RUN_JSON")
PROM_GATEWAY=$(jq -r '.prom_gateway' "$RUN_JSON")
INITIAL_PEERS=$(jq -r '.seeds[] | "--initial_peers " + .' "$RUN_JSON" | tr '\n' ' ')

# ── Launch one node per GPU ───────────────────────────────
for GPU_ID in "${GPUS[@]}"; do
    HOST_PORT=$((49200 + GPU_ID))
    LOG_FILE="${LOG_DIR}/server_gpu${GPU_ID}.log"
    KEY_FILE="${AGORA_DIR}/private_gpu${GPU_ID}.key"

    if [ -n "$AGORA_ANNOUNCE_PORT" ]; then
        ANNOUNCE_PORT=$((AGORA_ANNOUNCE_PORT + GPU_ID))
    else
        ANNOUNCE_PORT=$HOST_PORT
    fi

    ANNOUNCE_MADDRS="/ip4/${PUBLIC_IP}/tcp/${ANNOUNCE_PORT}"

    echo "[Agora] Launching node — GPU ${GPU_ID}, host_port ${HOST_PORT}, announce_port ${ANNOUNCE_PORT}"

    nohup env CUDA_VISIBLE_DEVICES=${GPU_ID} \
        "$PYTHON" "${AGORA_DIR}/agora/src/agora/run_server.py" \
            --gpu_id "${GPU_ID}" \
            --config "${RUN_CONFIG}" \
            --token "${AGORA_HF_TOKEN}" \
            --auth_server "${AUTH_SERVER}" \
            --prom_gateway "${PROM_GATEWAY}" \
            --host_maddrs "/ip4/0.0.0.0/tcp/${HOST_PORT}" \
            --announce_maddrs "${ANNOUNCE_MADDRS}" \
            ${INITIAL_PEERS} \
            ${AGORA_EMAIL:+--email "${AGORA_EMAIL}"} \
            --log_file "${LOG_FILE}" \
            --identity_path "${KEY_FILE}" \
        >> "${LOG_FILE}" 2>&1 &

    echo "[Agora] Node GPU ${GPU_ID} started (PID $!)"
    echo "[Agora] Logs: tail -f ${LOG_FILE}"
done

echo "[Agora] All nodes launched — https://agora.pluralis.ai/"
EOF
RUN chmod 755 /post_start.sh && sed -i 's/\r$//' /post_start.sh

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc || true

# =========================================================
# Platform start script
# =========================================================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh && sed -i 's/\r$//' /start.sh

# =========================================================
# Permissions
# =========================================================
RUN chown -R root:root /workspace || true

# =========================================================
# Ports
# 22    — SSH
# 80    — nginx landing page
# 8888  — Jupyter
# 6006  — TensorBoard
# 49200 — Agora node GPU 0
# 49201 — Agora node GPU 1 (if multi-GPU)
# =========================================================
EXPOSE 22 80 8888 6006 49200 49201

USER root
WORKDIR /root
CMD ["/bin/bash", "-c", "exec /bin/bash /start.sh"]
