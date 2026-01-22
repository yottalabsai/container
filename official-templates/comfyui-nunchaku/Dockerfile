ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG TORCH=""
ARG COMFYUI_HOST="0.0.0.0"
ARG COMFYUI_PORT="8188"
ARG COMFYUI_EXTRA_ARGS=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    COMFYUI_HOST=${COMFYUI_HOST} \
    COMFYUI_PORT=${COMFYUI_PORT} \
    COMFYUI_EXTRA_ARGS=${COMFYUI_EXTRA_ARGS}

WORKDIR /

# ---- workspace ----
RUN mkdir -p /workspace && chmod 777 /workspace

# ---- system tools & services ----
# Includes your requested toolchain + common runtime deps for OpenCV/video nodes.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs \
      sudo \
      openssh-server \
      nginx \
      tini \
      build-essential make g++ pkg-config \
      software-properties-common \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      acl bash tzdata locales \
      ffmpeg \
      libgl1 libglib2.0-0 libsm6 libxext6 libxrender1; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; locale-gen; update-locale; \
    mkdir -p /run/sshd; \
    rm -rf /var/lib/apt/lists/*

# ---- python ----
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" "python${PYTHON_VERSION}-distutils"; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
    python3 /tmp/get-pip.py; \
    rm -f /tmp/get-pip.py; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel; \
    rm -rf /var/lib/apt/lists/*

# ---- torch (optional via build-arg) ----
# Example:
#   --build-arg TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
RUN if [ -n "${TORCH}" ]; then python3 -m pip install --no-cache-dir ${TORCH}; fi

# ---- jupyter (start.sh may rely on it) ----
RUN python3 -m pip install --no-cache-dir -U jupyterlab

# ---- ComfyUI ----
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI && \
    python3 -m pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt

# ---- common python deps for popular custom_nodes (based on your logs) ----
RUN python3 -m pip install --no-cache-dir -U \
      pillow aiohttp \
      opencv-python-headless \
      matplotlib scikit-image \
      accelerate safetensors \
      imageio imageio-ffmpeg \
      numba llvmlite \
      gguf

# ---- fix diffusers/huggingface_hub mismatch (cached_download removal) ----
# Keep them modern and mutually compatible.
RUN python3 -m pip install --no-cache-dir -U \
      "huggingface_hub>=0.26,<1.0" \
      "diffusers>=0.30,<1.0" \
      "transformers>=4.41,<5.0"

# ---- custom nodes: ComfyUI-nunchaku (latest) ----
RUN mkdir -p /opt/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/nunchaku-ai/ComfyUI-nunchaku.git \
      /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku

# Install plugin deps if present (does not install backend engine wheels).
RUN set -eux; \
    if [ -f /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt ]; then \
      python3 -m pip install --no-cache-dir -r /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt; \
    fi

# Put installer workflow in default workflows for one-click backend install in UI.
RUN set -eux; \
    mkdir -p /opt/ComfyUI/user/default/workflows; \
    curl -fsSL "https://raw.githubusercontent.com/nunchaku-ai/ComfyUI-nunchaku/main/example_workflows/install_wheel.json" \
      -o /opt/ComfyUI/user/default/workflows/install_wheel.json || true

# ---- persistent models path ----
RUN mkdir -p /workspace/ComfyUI/models && \
    rm -rf /opt/ComfyUI/models && ln -s /workspace/ComfyUI/models /opt/ComfyUI/models

# ---- path compatibility (your pod had /home/ubuntu/ComfyUI) ----
RUN mkdir -p /home/ubuntu && ln -sfn /opt/ComfyUI /home/ubuntu/ComfyUI

# ---- create ubuntu user (used for running ComfyUI) ----
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace /opt/ComfyUI /home/ubuntu

# ---- ssh prep: let start.sh generate host keys at runtime if missing ----
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*

# ---- nginx/static (from container-template contexts) ----
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# ---- welcome ----
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m and \033[1;34mhttps://www.yottalabs.ai/\033[0m\n\n"' >> /root/.bashrc

# ---- start.sh (MUST NOT MODIFY) ----
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# ---- post_start.sh ----
# Requirement: print logs to console AND write to file for collection.
# We start ComfyUI as ubuntu, but tee runs in root shell so it can write stdout.
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG="/home/ubuntu/comfyui.log"
mkdir -p "$(dirname "$LOG")"
touch "$LOG"
chown ubuntu:ubuntu "$LOG" || true

if [ -d /opt/ComfyUI ]; then
  COMFY_DIR=/opt/ComfyUI
elif [ -d /home/ubuntu/ComfyUI ]; then
  COMFY_DIR=/home/ubuntu/ComfyUI
else
  echo "ComfyUI directory not found under /opt/ComfyUI or /home/ubuntu/ComfyUI" >&2
  exit 1
fi

echo "[post_start] Starting ComfyUI (logs -> $LOG AND stdout) ..."

# Run as ubuntu; pipe output to both file and container stdout.
# Background the whole pipeline so post_start can return.
(
  sudo -u ubuntu bash -lc "cd \"$COMFY_DIR\" && \
    python3 -u main.py \
      --listen \"${COMFYUI_HOST:-0.0.0.0}\" \
      --port \"${COMFYUI_PORT:-8188}\" \
      ${COMFYUI_EXTRA_ARGS:-}" 2>&1 | tee -a "$LOG"
) &

echo "[post_start] ComfyUI launch command submitted."
echo "[post_start] Tip: For Nunchaku backend, open workflow: user/default/workflows/install_wheel.json and run it in ComfyUI."
EOS
RUN chmod +x /post_start.sh

EXPOSE 22 8888 8188

# IMPORTANT: do NOT switch USER here.
# start.sh must run as root to start services (ssh/nginx) and generate host keys.
WORKDIR /root
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
