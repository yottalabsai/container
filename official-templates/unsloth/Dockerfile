# ===============================
# main stage
# ===============================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    VENV_PATH=/opt/venv

# -------------------------------
# System packages + tools
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git \
      sudo \
      openssh-server \
      nginx \
      tini \
      build-essential make g++ \
      software-properties-common \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Platform workaround:
# Platform runs: sshd -D && /start.sh
# "-D" blocks forever, so /start.sh never runs.
# Wrap sshd so "-D" daemonizes and exits 0.
# -------------------------------
RUN set -eux; \
    if [ -x /usr/sbin/sshd ] && [ ! -x /usr/sbin/sshd.real ]; then \
      mv /usr/sbin/sshd /usr/sbin/sshd.real; \
      cat > /usr/sbin/sshd <<'EOF'; \
#!/usr/bin/env bash
set -euo pipefail
REAL="/usr/sbin/sshd.real"
if [[ "${1:-}" == "-D" ]]; then
  shift
  exec "$REAL" "$@"
fi
if [[ " $* " == *" -D "* ]]; then
  args=()
  for a in "$@"; do
    [[ "$a" == "-D" ]] && continue
    args+=("$a")
  done
  exec "$REAL" "${args[@]}"
fi
exec "$REAL" "$@"
EOF
      chmod 755 /usr/sbin/sshd; \
    fi

# -------------------------------
# Python 3.11 + venv
# Ubuntu 22.04 默认不带 python3.11，使用 deadsnakes PPA
# -------------------------------
RUN set -eux; \
    add-apt-repository -y ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev; \
    rm -rf /var/lib/apt/lists/*; \
    python3.11 -m venv "${VENV_PATH}"; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir -U pip setuptools wheel

# 让 start.sh 里 "python3.11 -m jupyter ..." 一定命中 venv
RUN set -eux; \
    ln -sf "${VENV_PATH}/bin/python3.11" /usr/local/bin/python3.11; \
    ln -sf "${VENV_PATH}/bin/python" /usr/local/bin/python || true; \
    ln -sf "${VENV_PATH}/bin/pip" /usr/local/bin/pip || true

# 同时把 venv 放进系统默认 PATH（包含 sudo secure_path）
RUN set -eux; \
    echo 'export PATH=/opt/venv/bin:$PATH' >/etc/profile.d/venv.sh; \
    chmod 644 /etc/profile.d/venv.sh; \
    echo 'Defaults secure_path="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' >/etc/sudoers.d/99-secure-path; \
    chmod 0440 /etc/sudoers.d/99-secure-path

# -------------------------------
# Python packages: Unsloth + Jupyter + CLI tools
# -------------------------------
RUN set -eux; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch torchvision torchaudio; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir -U \
      unsloth \
      jupyterlab jupyter_server ipykernel \
      huggingface_hub datasets

# Unsloth pip-install 需要的额外项（只加不删）
RUN set -eux; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir xformers --no-deps; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir triton

# 便捷：把 jupyter/hf/datasets cli 做成全局可用
RUN set -eux; \
    ln -sf "${VENV_PATH}/bin/jupyter" /usr/local/bin/jupyter || true; \
    ln -sf "${VENV_PATH}/bin/huggingface-cli" /usr/local/bin/huggingface-cli || true; \
    ln -sf "${VENV_PATH}/bin/datasets-cli" /usr/local/bin/datasets-cli || true

# -------------------------------
# Users（兼容你 /entry.sh 里用的 unsloth，也兼容 start.sh 里 chown ubuntu）
# -------------------------------
RUN set -eux; \
    if ! id unsloth >/dev/null 2>&1; then useradd -m -s /bin/bash -u 1000 unsloth; fi; \
    if ! id ubuntu >/dev/null 2>&1; then useradd -m -s /bin/bash -u 1001 ubuntu; fi; \
    usermod -aG sudo unsloth; \
    usermod -aG sudo ubuntu; \
    echo "unsloth ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-unsloth; \
    echo "ubuntu  ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-ubuntu; \
    chmod 0440 /etc/sudoers.d/90-unsloth /etc/sudoers.d/90-ubuntu; \
    mkdir -p /workspace /workspace/work /workspace/unsloth-notebooks; \
    chown -R ubuntu:ubuntu /workspace || true

# -------------------------------
# sshd minimal dirs
# -------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd

# -------------------------------
# Branding（保持你的 --from=logo + echo cat 逻辑）
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh：必须原样保留（你明确要求不改）
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# 备用 entry（你之前用来手动起 jupyter 的方式也保留）
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

(/usr/sbin/sshd || true)

exec sudo -u unsloth -H bash -lc \
  '/opt/venv/bin/jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT:-8888} --no-browser --ServerApp.token="" --ServerApp.password="" --ServerApp.allow_origin="*" --ServerApp.root_dir=/workspace'
EOF
RUN chmod +x /entry.sh

EXPOSE 8888 22 80

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/start.sh"]
