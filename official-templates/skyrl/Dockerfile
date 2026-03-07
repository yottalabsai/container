# ===============================
# logo + scripts + proxy stages
# ===============================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY container-template/start.sh start.sh

# nginx config / landing page (keep as its own stage to match existing COPY --from=proxy)
FROM scratch AS proxy
# These two files must exist in the build context; adjust paths if not at root
COPY nginx.conf nginx.conf
COPY readme.html readme.html

# =========================================================
# Base image
# =========================================================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

# =========================================================
# System packages
# =========================================================
USER root
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
      python3 python3-venv python3-pip \
      software-properties-common \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Users: ubuntu (compat)
# =========================================================
RUN set -eux; \
    useradd -ms /bin/bash ubuntu || true; \
    usermod -aG sudo ubuntu || true; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    echo "ubuntu:ubuntu" | chpasswd || true

# =========================================================
# Python 3.11
# =========================================================
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      python3.11 \
      python3.11-venv \
      python3.11-distutils; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Default Python -> 3.11
# =========================================================
RUN set -eux; \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 311; \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 311; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.11; \
    python3.11 -m pip install --no-cache-dir -U pip setuptools wheel

# =========================================================
# Python tools
# =========================================================
RUN set -eux; \
    python -m pip install --no-cache-dir \
      ray[default,data,train,tune,serve]==2.51.1 \
      torch>=2.0.0 \
      transformers \
      datasets \
      accelerate \
      tensorboard \
      wandb \
      jupyterlab \
      ipywidgets \
      notebook \
      huggingface_hub \
      bitsandbytes \
      unsloth

# =========================================================
# Megatron-LM (optional)
# =========================================================
RUN git clone --depth 1 https://github.com/NVIDIA/Megatron-LM.git /opt/megatron-lm && \
    pip install -e /opt/megatron-lm

# =========================================================
# nccl-tests
# =========================================================
RUN set -eux; \
    git clone --depth 1 https://github.com/NVIDIA/nccl-tests.git /tmp/nccl-tests; \
    make -C /tmp/nccl-tests -j"$(nproc)"; \
    mkdir -p /usr/local/bin/nccl-tests; \
    cp -a /tmp/nccl-tests/build/* /usr/local/bin/nccl-tests/; \
    rm -rf /tmp/nccl-tests

# =========================================================
# SSH hardening (platform may override anyway)
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# =========================================================
# nginx + README (optional)
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# start.sh (must be kept as-is)
# =========================================================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /home/ubuntu/.bashrc || true

COPY SkyRL_Demo.ipynb /workspace/
# =========================================================
# post_start hook (important)
# - Platform PID1 actually runs: sudo -E /start.sh
# - ENTRYPOINT/CMD is unreliable; injecting via /post_start.sh is most stable
# - No root dependency, does not touch /home/ubuntu, logs written to /workspace
# =========================================================
RUN set -eux; \
  cat > /post_start.sh <<'SH'
#!/usr/bin/env bash
set -e

LOG_DIR="/workspace"
TB_LOG="${LOG_DIR}/tensorboard.log"

# Log whether we were actually invoked
echo "[post_start] invoked at $(date -Is) uid=$(id -u) gid=$(id -g)" >> "${TB_LOG}" 2>/dev/null || true

# Avoid duplicate startup (on container restart or multiple invocations)
if ss -lntp 2>/dev/null | grep -q ':6006'; then
  echo "[post_start] tensorboard already listening on 6006" >> "${TB_LOG}" 2>/dev/null || true
  exit 0
fi

# Start TensorBoard (background), append logs to /workspace (usually a writable volume)
nohup tensorboard \
  --logdir=/workspace \
  --host=0.0.0.0 \
  --port=6006 \
  >> "${TB_LOG}" 2>&1 &

sleep 1
ss -lntp 2>/dev/null | grep 6006 >> "${TB_LOG}" 2>&1 || true
echo "[post_start] tensorboard launch done at $(date -Is)" >> "${TB_LOG}" 2>/dev/null || true
SH
RUN chmod +x /post_start.sh

# =========================================================
# Permissions (avoid assuming /home/ubuntu is writable; /workspace is usually a writable mount)
# =========================================================
RUN chown -R ubuntu:ubuntu /workspace /home/ubuntu || true

# =========================================================
# Ports
# =========================================================
EXPOSE 22 80 8888 6006

# =========================================================
# Entrypoint (may be overridden by the platform; keeping it is harmless)
# =========================================================
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-lc", "echo 'Image ready. Platform will run /start.sh.'; sleep infinity"]
