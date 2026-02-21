# ==============================
# Miles AI Agent image (official-templates/miles)
# - Base: official radixark/miles
# - Layered: tools + SSH + Nginx + branding
# ==============================

ARG BASE_IMAGE="radixark/miles:latest"
FROM ${BASE_IMAGE} AS base

# ---- Environment variable configuration ----
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=ubuntu 
# ==============================
# runtime: tools + Branding + SSH
# ==============================
FROM base AS runtime

USER root
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ---- Critical patch: fix apt-get update failures caused by /var/lib/apt/lists permission errors in some base images ----
RUN set -eux; \
    mkdir -p /var/lib/apt/lists/partial; \
    chmod -R 755 /var/lib/apt/lists || true

# ---- Utilities + SSH dependencies + Nginx ----
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      vim \
      htop \
      tmux \
      nano \
      iputils-ping \
      lsof \
      tree \
      jq \
      net-tools \
      netcat-openbsd \
      procps \
      iproute2 \
      rsync \
      openssh-server \
      sudo \
      ca-certificates \
      curl \
      wget \
      git \
      build-essential \
      pkg-config \
      nginx \
    ; \
    mkdir -p /var/run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ---- Python dependency update ----
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel

# ---- Jupyter + common CLI tools ----
RUN python3 -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

# ---- Dynamically detect Python version and create python3.11 symlink (for start.sh compatibility) ----
RUN set -eux; \
    PYTHON_BIN=$(which python3); \
    echo "Detected Python: $PYTHON_BIN"; \
    ln -sf "$PYTHON_BIN" /usr/bin/python3.11; \
    python3.11 --version

# ---- SSH configuration: more secure by default (recommended for production: key-only) ----
RUN set -eux; \
    sed -i \
      -e 's@^#\?PermitRootLogin .*@PermitRootLogin prohibit-password@g' \
      -e 's@^#\?PasswordAuthentication .*@PasswordAuthentication no@g' \
      -e 's@^#\?PubkeyAuthentication .*@PubkeyAuthentication yes@g' \
      -e 's@^#\?UsePAM .*@UsePAM yes@g' \
      /etc/ssh/sshd_config

# ---- COPY official template start.sh (from container-template/start.sh) ----
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ---- Critical fallback: auto-start sshd + nginx when platform overrides PID1/ENTRYPOINT ----
RUN cat >> /etc/bash.bashrc <<'EOS'

# ---- Yotta: auto-start services when a shell is opened (platform may override PID1) ----
if [ "${SSH_ENABLE:-1}" != "0" ] && command -v sshd >/dev/null 2>&1; then
  if ! pgrep -x sshd >/dev/null 2>&1; then
    mkdir -p /var/run/sshd
    [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A >/dev/null 2>&1 || true
    /usr/sbin/sshd -p "${SSH_PORT:-22}" >/dev/null 2>&1 || true
  fi
fi

# Auto-start nginx
if command -v nginx >/dev/null 2>&1; then
  if ! pgrep -x nginx >/dev/null 2>&1; then
    service nginx start >/dev/null 2>&1 || true
  fi
fi
# ------------------------------------------------------------------------------------
EOS

# ---- Yotta branding elements ----
# 1) Create branding text
RUN set -eux; \
    echo "YottaLabs AI - Miles AI Agent Platform" > /etc/yotta.txt; \
    cat /etc/yotta.txt

# 2) /etc/profile.d - applies to all login scenarios
RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

# 3) Append to root bashrc (only applies to root's interactive bash)
RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt 2>/dev/null || true' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

COPY Miles_Demo.ipynb /workspace/

# ---- Allow scripts to be absent: avoid build fail ----
RUN chmod +x /post_start.sh /start.sh 2>/dev/null || true

# ---- Expose ports ----
EXPOSE 22 80 8888
USER root
WORKDIR /root

# ---- Default entrypoint ----
ENTRYPOINT ["/start.sh"]

