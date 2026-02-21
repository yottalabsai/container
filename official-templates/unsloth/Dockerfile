# ===============================
# logo + scripts stages
# ===============================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY container-template/start.sh start.sh

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
# System packages
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
# sshd wrapper (unchanged)
# -------------------------------
RUN <<'EOF'
set -eux
if [ -x /usr/sbin/sshd ] && [ ! -x /usr/sbin/sshd.real ]; then
  mv /usr/sbin/sshd /usr/sbin/sshd.real
  cat > /usr/sbin/sshd <<'EOSSHD'
#!/usr/bin/env bash
set -euo pipefail
REAL="/usr/sbin/sshd.real"
if [[ " $* " == *" -D "* ]]; then
  args=()
  for a in "$@"; do
    [[ "$a" == "-D" ]] && continue
    args+=("$a")
  done
  exec "$REAL" "${args[@]}"
fi
exec "$REAL" "$@"
EOSSHD
  chmod 755 /usr/sbin/sshd
fi
EOF

# -------------------------------
# Python 3.11 + venv
# -------------------------------
RUN set -eux; \
    add-apt-repository -y ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev; \
    rm -rf /var/lib/apt/lists/*; \
    python3.11 -m venv "${VENV_PATH}"; \
    "${VENV_PATH}/bin/pip" install -U pip setuptools wheel

RUN ln -sf "${VENV_PATH}/bin/python3.11" /usr/local/bin/python3.11 && \
    ln -sf "${VENV_PATH}/bin/python" /usr/local/bin/python || true && \
    ln -sf "${VENV_PATH}/bin/pip" /usr/local/bin/pip || true

RUN echo 'export PATH=/opt/venv/bin:$PATH' >/etc/profile.d/venv.sh && \
    chmod 644 /etc/profile.d/venv.sh && \
    echo 'Defaults secure_path="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' \
      >/etc/sudoers.d/99-secure-path

# -------------------------------
# Python packages (Unsloth)
# -------------------------------
RUN set -eux; \
    pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch torchvision torchaudio; \
    pip install --no-cache-dir \
      unsloth \
      jupyterlab jupyter_server ipykernel \
      huggingface_hub datasets; \
    pip install --no-cache-dir xformers --no-deps; \
    pip install --no-cache-dir triton

RUN ln -sf "${VENV_PATH}/bin/jupyter" /usr/local/bin/jupyter || true

# -------------------------------
# Users
# -------------------------------
RUN set -eux; \
    useradd -m -s /bin/bash -u 1000 unsloth || true; \
    useradd -m -s /bin/bash -u 1001 ubuntu  || true; \
    usermod -aG sudo unsloth; \
    usermod -aG sudo ubuntu; \
    echo "unsloth ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-unsloth; \
    echo "ubuntu  ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-ubuntu; \
    chmod 0440 /etc/sudoers.d/90-unsloth /etc/sudoers.d/90-ubuntu; \
    mkdir -p /workspace /workspace/work /workspace/unsloth-notebooks; \
    chown -R unsloth:unsloth /workspace

# =========================================================
# Download Unsloth notebooks templates and flatten structure
# =========================================================
RUN set -eux; \
    cd /tmp; \
    git clone --depth=1 https://github.com/unslothai/notebooks.git unsloth-notebooks-src; \
    \
    # Ensure target directory exists
    mkdir -p /workspace/unsloth-notebooks; \
    \
    # Copy all scripts from original_template to the target directory
    cp -a unsloth-notebooks-src/original_template/. /workspace/unsloth-notebooks/; \
    \
    # Also copy template.ipynb (if needed)
    cp -a unsloth-notebooks-src/template.ipynb /workspace/unsloth-notebooks/ || true; \
    \
    # Fix permissions (Jupyter runs as unsloth user)
    chown -R unsloth:unsloth /workspace/unsloth-notebooks; \
    \
    # Cleanup
    rm -rf /tmp/unsloth-notebooks-src


# =========================================================
# Key fix: do not COPY unsloth-notebooks directly
#    instead COPY the entire build context, then copy if present, skip if absent
# =========================================================
COPY . /__build_context__

RUN set -eux; \
    if [ -d /__build_context__/unsloth-notebooks ]; then \
      cp -a /__build_context__/unsloth-notebooks/. /workspace/unsloth-notebooks/; \
      chown -R unsloth:unsloth /workspace/unsloth-notebooks; \
    fi; \
    rm -rf /__build_context__

# -------------------------------
# sshd dirs
# -------------------------------
RUN mkdir -p /var/run/sshd

# -------------------------------
# Branding
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh (must not change)
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# entry.sh
# -------------------------------
RUN <<'EOF'
cat > /entry.sh <<'EOENTRY'
#!/usr/bin/env bash
set -euo pipefail
(/usr/sbin/sshd || true)
exec sudo -u unsloth -H bash -lc \
  'jupyter lab --ip=0.0.0.0 --port=${JUPYTER_PORT:-8888} --no-browser \
   --ServerApp.token="" --ServerApp.password="" \
   --ServerApp.allow_origin="*" \
   --ServerApp.root_dir=/workspace'
EOENTRY
chmod 755 /entry.sh
EOF

EXPOSE 8888 22 80

ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/start.sh"]
