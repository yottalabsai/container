# Unsloth-ready CUDA 12.8 image
# Includes: PyTorch cu128 + Unsloth + JupyterLab + SSH
# Tools: vim, jq, tree, htop, nccl-tests, tmux, rsync, huggingface-cli, datasets-cli
# Branding: yotta.txt printed in root interactive bash

FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    JUPYTER_PORT=8888 \
    JUPYTER_PASSWORD=unsloth \
    USER_PASSWORD=unsloth \
    VENV_PATH=/opt/venv

# -------------------------------
# System deps + tools you requested
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      sudo openssh-server \
      tini \
      build-essential \
      software-properties-common \
      # tools
      vim jq tree htop tmux rsync \
      # nccl tests (repo package name on Ubuntu)
      nccl-tests \
      # (optional but handy)
      pciutils iproute2 net-tools lsof procps; \
    add-apt-repository -y ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Python venv
# -------------------------------
RUN set -eux; \
    python3.11 -m venv "${VENV_PATH}"; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir -U pip setuptools wheel

ENV PATH="${VENV_PATH}/bin:${PATH}"

# -------------------------------
# PyTorch cu128 + Unsloth + Jupyter + CLIs
# huggingface-cli -> huggingface_hub
# datasets-cli     -> datasets
# -------------------------------
RUN set -eux; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch torchvision torchaudio; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir -U \
      unsloth \
      jupyterlab jupyter_server ipykernel \
      huggingface_hub datasets \
      numpy pandas matplotlib

# -------------------------------
# User: unsloth (run training/jupyter as non-root)
# -------------------------------
RUN set -eux; \
    groupadd -g 1000 unsloth || true; \
    useradd -m -u 1000 -g 1000 -s /bin/bash unsloth || true; \
    echo "unsloth ALL=(ALL) ALL" > /etc/sudoers.d/unsloth; \
    chmod 0440 /etc/sudoers.d/unsloth; \
    mkdir -p /home/unsloth/.ssh /workspace/work /workspace/unsloth-notebooks; \
    chmod 700 /home/unsloth/.ssh; \
    chown -R unsloth:unsloth /home/unsloth /workspace

# -------------------------------
# SSHD setup
# -------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config; \
    echo "AllowUsers unsloth" >> /etc/ssh/sshd_config

# -------------------------------
# Unsloth notebooks (best-effort)
# -------------------------------
RUN set -eux; \
    git clone --depth 1 https://github.com/unslothai/notebooks /workspace/unsloth-notebooks || true; \
    chown -R unsloth:unsloth /workspace/unsloth-notebooks || true

# -------------------------------
# Branding (as you requested)
# -------------------------------
COPY yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# Entrypoint
# -------------------------------
RUN set -eux; \
    cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# SSH key injection (env: SSH_KEY)
if [[ -n "${SSH_KEY:-}" ]]; then
  install -d -m 700 -o unsloth -g unsloth /home/unsloth/.ssh
  echo "${SSH_KEY}" > /home/unsloth/.ssh/authorized_keys
  chown unsloth:unsloth /home/unsloth/.ssh/authorized_keys
  chmod 600 /home/unsloth/.ssh/authorized_keys
fi

# Set sudo password (env: USER_PASSWORD)
echo "unsloth:${USER_PASSWORD:-unsloth}" | chpasswd

# Start sshd
/usr/sbin/sshd

# Jupyter password hash from plaintext JUPYTER_PASSWORD
JUPYTER_PW="${JUPYTER_PASSWORD:-unsloth}"
HASH="$(python3.11 - <<PY
from jupyter_server.auth import passwd
print(passwd("${JUPYTER_PW}"))
PY
)"

# Launch Jupyter Lab as non-root.
# IMPORTANT: use absolute path to avoid sudo PATH stripping.
exec sudo -u unsloth -H bash -lc \
  "/opt/venv/bin/jupyter lab \
    --ip=0.0.0.0 \
    --port=${JUPYTER_PORT:-8888} \
    --no-browser \
    --ServerApp.token='' \
    --ServerApp.password='${HASH}' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace"
EOF
RUN chmod +x /entry.sh

EXPOSE 8888 22

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entry.sh"]
