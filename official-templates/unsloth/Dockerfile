# ===============================
# logo stage (required for COPY --from=logo yotta.txt ...)
# ===============================
FROM scratch AS logo
COPY yotta.txt /yotta.txt

# ===============================
# scripts stage (start.sh must be preserved as-is)
# ===============================
FROM scratch AS scripts
# 这里假设你的构建上下文里有 container-template/start.sh（你说的 /container-template/start.sh）
COPY container-template/start.sh /start.sh

# ===============================
# main stage
# ===============================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

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
# System deps + tools
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git \
      sudo openssh-server \
      nginx \
      tini \
      build-essential \
      software-properties-common \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      make g++ \
      libnccl2 libnccl-dev; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Build nccl-tests (needs nvcc from devel image)
# -------------------------------
ARG NCCL_TESTS_REF=master
RUN set -eux; \
    git clone --depth 1 --branch "${NCCL_TESTS_REF}" https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests; \
    make -C /opt/nccl-tests -j"$(nproc)" CUDA_HOME=/usr/local/cuda; \
    ln -sf /opt/nccl-tests/build/all_reduce_perf /usr/local/bin/all_reduce_perf || true; \
    ln -sf /opt/nccl-tests/build/all_gather_perf /usr/local/bin/all_gather_perf || true; \
    ln -sf /opt/nccl-tests/build/reduce_scatter_perf /usr/local/bin/reduce_scatter_perf || true; \
    ln -sf /opt/nccl-tests/build/broadcast_perf /usr/local/bin/broadcast_perf || true

# -------------------------------
# Python 3.11 + venv
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3.11 python3.11-venv python3.11-dev; \
    rm -rf /var/lib/apt/lists/*; \
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
# Make "python3.11 -m jupyter" work for start.sh WITHOUT changing start.sh
# start.sh uses: nohup python3.11 -m jupyter lab ...
# So we ensure python3.11 resolves to venv python3.11 (and thus sees jupyter).
# -------------------------------
RUN set -eux; \
    ln -sf "${VENV_PATH}/bin/python3.11" /usr/local/bin/python3.11; \
    ln -sf "${VENV_PATH}/bin/python" /usr/local/bin/python || true; \
    ln -sf "${VENV_PATH}/bin/jupyter" /usr/local/bin/jupyter || true; \
    ln -sf "${VENV_PATH}/bin/huggingface-cli" /usr/local/bin/huggingface-cli || true; \
    ln -sf "${VENV_PATH}/bin/datasets-cli" /usr/local/bin/datasets-cli || true

# -------------------------------
# User: unsloth  (keep existing)
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
# User: ubuntu (required by start.sh: sudo chown ubuntu:ubuntu /workspace)
# -------------------------------
RUN set -eux; \
    groupadd -g 1001 ubuntu || true; \
    useradd -m -u 1001 -g 1001 -s /bin/bash ubuntu || true; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu; \
    chown -R ubuntu:ubuntu /workspace || true

# -------------------------------
# SSHD setup
# -------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config; \
    echo "AllowUsers unsloth ubuntu" >> /etc/ssh/sshd_config

# -------------------------------
# Unsloth notebooks (best-effort)
# -------------------------------
RUN set -eux; \
    git clone --depth 1 https://github.com/unslothai/notebooks /workspace/unsloth-notebooks || true; \
    chown -R unsloth:unsloth /workspace/unsloth-notebooks || true

# -------------------------------
# Branding  (keep your exact lines style)
# -------------------------------
COPY --from=logo /yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh (MUST be preserved as-is)
# -------------------------------
COPY --from=scripts /start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# Entrypoint (keep existing /entry.sh)
# -------------------------------
RUN set -eux; \
    cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${SSH_KEY:-}" ]]; then
  install -d -m 700 -o unsloth -g unsloth /home/unsloth/.ssh
  echo "${SSH_KEY}" > /home/unsloth/.ssh/authorized_keys
  chown unsloth:unsloth /home/unsloth/.ssh/authorized_keys
  chmod 600 /home/unsloth/.ssh/authorized_keys
fi

echo "unsloth:${USER_PASSWORD:-unsloth}" | chpasswd
/usr/sbin/sshd

JUPYTER_PW="${JUPYTER_PASSWORD:-unsloth}"
HASH="$(python3.11 - <<PY
from jupyter_server.auth import passwd
print(passwd("${JUPYTER_PW}"))
PY
)"

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

EXPOSE 8888 22 80

ENTRYPOINT ["/usr/bin/tini", "--"]
# 默认改成 /start.sh，更兼容你平台“覆盖 CMD”场景；/entry.sh 仍然保留可手动跑
CMD ["/start.sh"]
