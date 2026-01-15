# official-templates/unsloth/Dockerfile
#
# IMPORTANT:
# - This Dockerfile expects build context to be repo root (so it can COPY container-template/start.sh)
#   Example:
#     docker build -f official-templates/unsloth/Dockerfile -t unsloth-ssh .
#
# Goals:
# - Install tools: vim, jq, tree, htop, tmux, rsync
# - Install/enable SSH (openssh-server) + robust autostart (even if platform overrides entrypoint)
# - Install huggingface-cli, datasets-cli
# - Build nccl-tests
# - Add Yotta branding into shells

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
      vim jq tree htop tmux rsync \
      netcat-openbsd procps net-tools \
      iproute2 \
      python3 python3-pip python3-venv \
    && mkdir -p /var/run/sshd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Python packages: CLI tools + common LLM stack deps
# - huggingface-cli comes from huggingface_hub
# - datasets-cli comes from datasets
# -----------------------------------------------------------------------------
RUN python3 -m pip install --no-cache-dir -U pip setuptools wheel && \
    python3 -m pip install --no-cache-dir \
      huggingface_hub \
      datasets \
      accelerate \
      safetensors \
      transformers \
      peft \
      trl \
      sentencepiece \
      bitsandbytes

# Optional: Unsloth (best-effort; may depend on CUDA/Torch combo)
RUN python3 -m pip install --no-cache-dir unsloth || true

# -----------------------------------------------------------------------------
# NCCL tests (best-effort compile)
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
# SSH defaults: key-based login on by default, password auth off
# -----------------------------------------------------------------------------
RUN sed -i \
  -e 's@^#\?PermitRootLogin .*@PermitRootLogin prohibit-password@g' \
  -e 's@^#\?PasswordAuthentication .*@PasswordAuthentication no@g' \
  -e 's@^#\?PubkeyAuthentication .*@PubkeyAuthentication yes@g' \
  /etc/ssh/sshd_config


# -----------------------------------------------------------------------------
# Copy official start script (from repo root): container-template/start.sh
# This matches "official-templates/pytorch/Dockerfile" pattern you referenced.
# -----------------------------------------------------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -----------------------------------------------------------------------------
# CRITICAL FALLBACK:
# Your platform may override ENTRYPOINT/CMD and run its own PID1 script.
# In that case, start.sh won't run. But you still open a shell to get in.
# So: auto-start sshd from /etc/bash.bashrc whenever a shell is opened.
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
# Branding / commercialization elements
# - /etc/profile.d applies broadly (ssh, bash, login shells)
# - also inject into root bashrc as you requested
# -----------------------------------------------------------------------------
RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# -----------------------------------------------------------------------------
# Expose ports commonly used in templates
# -----------------------------------------------------------------------------
EXPOSE 22 8888

# -----------------------------------------------------------------------------
# Default entrypoint: start.sh (if platform respects it)
# If platform overrides, /etc/bash.bashrc fallback will still start sshd when you open a shell.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/start.sh"]
