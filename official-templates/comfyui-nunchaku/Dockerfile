# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG TORCH=""
ARG COMFYUI_HOST="0.0.0.0"
ARG COMFYUI_PORT="8188"
ARG COMFYUI_EXTRA_ARGS=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
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
RUN mkdir -p /workspace && chmod 777 /workspace

# ===== System deps =====
# Notes:
# - ffmpeg + libgl1/libglib2.0-0 etc: common deps for OpenCV/video nodes
# - build-essential/pkg-config: needed by some Python wheels that compile
# - extra tools list: vim/jq/tree/htop/tmux/rsync/pciutils/iproute2/net-tools/lsof/procps/make/g++
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs \
      sudo openssh-server nginx tini \
      software-properties-common \
      build-essential make g++ pkg-config \
      ffmpeg \
      acl bash tzdata locales \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; locale-gen; update-locale; \
    mkdir -p /run/sshd; \
    rm -rf /var/lib/apt/lists/*

# ===== Python & Pip =====
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
    python3 -m pip install --no-cache-dir -U pip setuptools wheel

# ===== Torch (optional) =====
# Example build-arg:
#   TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121"
RUN if [ -n "${TORCH}" ]; then python3 -m pip install --no-cache-dir ${TORCH}; fi

# ===== Jupyter (start.sh expects it) =====
RUN python3 -m pip install --no-cache-dir -U jupyterlab

# ===== Install ComfyUI =====
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI && \
    python3 -m pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt

# ===== Common deps for popular custom nodes (avoid "module not found" at runtime) =====
# Your logs showed missing: PIL(a.k.a pillow), aiohttp, torch, cv2, matplotlib, accelerate, gguf, numba, skimage, imageio_ffmpeg
RUN python3 -m pip install --no-cache-dir -U \
      pillow aiohttp \
      opencv-python-headless matplotlib \
      accelerate safetensors \
      imageio imageio-ffmpeg \
      scikit-image \
      numba llvmlite \
      gguf

# ===== Fix diffusers/huggingface_hub mismatch (cached_download removal) =====
# If diffusers is too old while huggingface_hub is new, you get:
#   ImportError: cannot import name 'cached_download' from 'huggingface_hub'
# So we bump diffusers to a modern version (and keep hub modern as well).
RUN python3 -m pip install --no-cache-dir -U \
      "huggingface_hub>=0.26,<1.0" \
      "diffusers>=0.30,<1.0" \
      "transformers>=4.41,<5.0"

# ===== Custom Nodes: ComfyUI-nunchaku (plugin) =====
# Repo (upstream): nunchaku-ai/ComfyUI-nunchaku  citeturn0search3
RUN mkdir -p /opt/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/nunchaku-ai/ComfyUI-nunchaku.git \
      /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku

# Install plugin deps if the repo provides them (does NOT install backend wheel).
RUN set -eux; \
    if [ -f /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt ]; then \
      python3 -m pip install --no-cache-dir -r /opt/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt; \
    fi

# (Optional) Copy the installer workflow into the image for convenience.
# The backend engine is distributed as wheels via GitHub Releases / HF; the plugin can install them via install_wheel.json workflow. citeturn2search0turn2search7
RUN set -eux; \
    mkdir -p /opt/ComfyUI/user/default/workflows; \
    curl -fsSL "https://raw.githubusercontent.com/nunchaku-ai/ComfyUI-nunchaku/main/example_workflows/install_wheel.json" \
      -o /opt/ComfyUI/user/default/workflows/install_wheel.json || true

# ===== Models dir to persistent path =====
RUN mkdir -p /workspace/ComfyUI/models && \
    rm -rf /opt/ComfyUI/models && ln -s /workspace/ComfyUI/models /opt/ComfyUI/models

# ===== Path compatibility for your pod =====
RUN mkdir -p /home/ubuntu && ln -sfn /opt/ComfyUI /home/ubuntu/ComfyUI

# ===== User & Perm =====
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace /opt/ComfyUI /home/ubuntu

# ===== SSH prep (start.sh prints keys; regenerate at runtime) =====
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*

# ===== Nginx & Static =====
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# Welcome Message (keep original behavior)
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m and \033[1;34mhttps://www.yottalabs.ai/\033[0m\n\n"' >> /root/.bashrc

# ===== Start & post_start =====
# IMPORTANT: container-template/start.sh must remain unchanged (we only copy it).
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# post_start: start ComfyUI in the background (loads custom_nodes)
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/comfyui.log
mkdir -p /workspace

if [ -d /opt/ComfyUI ]; then
  COMFY_DIR=/opt/ComfyUI
elif [ -d /home/ubuntu/ComfyUI ]; then
  COMFY_DIR=/home/ubuntu/ComfyUI
else
  echo "ComfyUI directory not found under /opt/ComfyUI or /home/ubuntu/ComfyUI" >&2
  exit 1
fi

# Run as ubuntu so any downloaded workflows/models land in the user's space.
sudo -u ubuntu bash -lc "cd \"$COMFY_DIR\" && \
  python3 -u main.py \
    --listen \"${COMFYUI_HOST:-0.0.0.0}\" \
    --port   \"${COMFYUI_PORT:-8188}\" \
    ${COMFYUI_EXTRA_ARGS:-} \
  >> \"$LOG\" 2>&1 &"

echo "ComfyUI started on ${COMFYUI_HOST:-0.0.0.0}:${COMFYUI_PORT:-8188}. Logs: $LOG"
echo "If Nunchaku nodes show 'backend not installed', open workflow: user/default/workflows/install_wheel.json and run it in ComfyUI."
EOS
RUN chmod +x /post_start.sh

EXPOSE 8188

USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
