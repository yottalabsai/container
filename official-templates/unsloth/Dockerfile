ARG BASE_IMAGE=pytorch/pytorch:2.5.1-cuda12.1-cudnn9-runtime
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-lc"]

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      build-essential pkg-config \
      openssh-server sudo \
      nginx \
      vim jq tree htop tmux rsync \
      netcat-openbsd procps net-tools \
      iproute2 \
      python3 python3-pip python3-venv \
    && mkdir -p /var/run/sshd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Python packages (Unsloth + CLI tools)
# NOTE: Unsloth install varies by CUDA/Torch; adjust if you pin different stack.
# -----------------------------------------------------------------------------
RUN python3 -m pip install --no-cache-dir -U pip setuptools wheel && \
    python3 -m pip install --no-cache-dir \
      huggingface_hub \
      datasets \
      accelerate \
      safetensors \
      bitsandbytes \
      transformers \
      peft \
      trl \
      sentencepiece

# (Optional) Unsloth itself
# If you have a pinned/known-good version, replace "unsloth" with "unsloth==x.y.z"
RUN python3 -m pip install --no-cache-dir unsloth || true

# -----------------------------------------------------------------------------
# NCCL tests (best effort)
# - Some bases may already include NCCL runtime; this builds nccl-tests binaries.
# -----------------------------------------------------------------------------
ARG INSTALL_NCCL_TESTS=1
RUN if [[ "${INSTALL_NCCL_TESTS}" == "1" ]]; then \
      set -eux; \
      mkdir -p /opt/nccl-tests && \
      git clone --depth 1 https://github.com/NVIDIA/nccl-tests /opt/nccl-tests/src && \
      make -C /opt/nccl-tests/src MPI=0 -j"$(nproc)" && \
      ln -sf /opt/nccl-tests/src/build/* /usr/local/bin/ || true; \
    fi

# -----------------------------------------------------------------------------
# SSH hardening defaults (key-based by default)
# -----------------------------------------------------------------------------
RUN sed -i \
      -e 's@^#\?PermitRootLogin .*@PermitRootLogin prohibit-password@g' \
      -e 's@^#\?PasswordAuthentication .*@PasswordAuthentication no@g' \
      -e 's@^#\?PubkeyAuthentication .*@PubkeyAuthentication yes@g' \
      -e 's@^#\?UsePAM .*@UsePAM yes@g' \
      /etc/ssh/sshd_config

# -----------------------------------------------------------------------------
# Copy official start script (same behavior as pytorch template)
# -----------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

# -----------------------------------------------------------------------------
# CRITICAL: Fallback auto-start sshd when platform overrides ENTRYPOINT/CMD
# This matches your real situation: PID1 is platform script, you enter via shell.
# When a shell opens, we ensure sshd is running.
# -----------------------------------------------------------------------------
RUN cat >> /etc/bash.bashrc <<'EOS'

# ---- Yotta: auto-start sshd when a shell is opened (platform may override PID1) ----
if [ "${SSH_ENABLE:-1}" != "0" ] && command -v sshd >/dev/null 2>&1; then
  if ! pgrep -x sshd >/dev/null 2>&1; then
    mkdir -p /var/run/sshd
    # Generate host keys if missing
    [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A >/dev/null 2>&1 || true
    /usr/sbin/sshd -p "${SSH_PORT:-22}" >/dev/null 2>&1 || true
  fi
fi
# ------------------------------------------------------------------------------------
EOS

# -----------------------------------------------------------------------------
# Your branding / commercialization elements
# -----------------------------------------------------------------------------
# If you have /yotta/tools/info.sh or /etc/yotta.txt baked into image, keep it.
RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

# Keep your exact bashrc injections too (as requested)
RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# -----------------------------------------------------------------------------
# Ports (SSH / Jupyter / Nginx)
# -----------------------------------------------------------------------------
EXPOSE 22 8888 80

# Default behavior: run official start.sh (when ENTRYPOINT/CMD is respected)
# If platform overrides, bash.bashrc fallback will still start sshd when you open a shell.
ENTRYPOINT ["/start.sh"]
