# ===============================
# comfyui-nunchaku (FULL)
# - start.sh must NOT be changed (copied verbatim from scripts context)
# - post_start.sh only starts ComfyUI (no model downloads)
# - ComfyUI logs go to CONSOLE ONLY (stdout/stderr) for easy collection
# ===============================

# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"

# You can override at build time, e.g.
#   --build-arg TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128"
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128"

ARG COMFYUI_HOST="0.0.0.0"
ARG COMFYUI_PORT="8188"
ARG COMFYUI_EXTRA_ARGS=""

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH

# -------------------------------
# System deps + tools (your list + comfy deps)
# -------------------------------
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
      # OpenCV runtime libs
      libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    ; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; locale-gen; update-locale; \
    mkdir -p /run/sshd; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Python 3.11 + pip
# -------------------------------
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" \
      "python${PYTHON_VERSION}-dev" \
      "python${PYTHON_VERSION}-venv" \
      "python${PYTHON_VERSION}-distutils" \
    ; \
    ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/bin/python; \
    ln -sf "/usr/bin/python${PYTHON_VERSION}" /usr/bin/python3; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
    python3 /tmp/get-pip.py; \
    rm -f /tmp/get-pip.py; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Torch (default cu128, override via build-arg TORCH)
# -------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir ${TORCH}; \
    python3 -c "import torch; print('torch=', torch.__version__, 'cuda=', torch.version.cuda, 'available=', torch.cuda.is_available())"

# -------------------------------
# Common python deps to avoid the missing-module storm
# (covers PIL/aiohttp/cv2/matplotlib/skimage/accelerate/gguf/numba etc.)
# -------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U \
      pillow aiohttp \
      opencv-python-headless \
      matplotlib scikit-image \
      accelerate safetensors \
      imageio imageio-ffmpeg \
      numba llvmlite \
      gguf \
      lark \
      jupyterlab

# Fix diffusers <-> huggingface_hub mismatch (cached_download removal)
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U \
      "huggingface_hub>=0.26,<1.0" \
      "diffusers>=0.30,<1.0" \
      "transformers>=4.41,<5.0"

# -------------------------------
# Create ubuntu user (ComfyUI runs as ubuntu)
# NOTE: container-template/start.sh must run as root (ssh/nginx).
# -------------------------------
RUN set -eux; \
    useradd -ms /bin/bash ubuntu; \
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu; \
    chmod 0440 /etc/sudoers.d/90-ubuntu

# -------------------------------
# ComfyUI (code inside image; you can still mount models/custom_nodes via S3)
# -------------------------------
RUN set -eux; \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /home/ubuntu/ComfyUI; \
    chown -R ubuntu:ubuntu /home/ubuntu/ComfyUI; \
    python3 -m pip install --no-cache-dir -r /home/ubuntu/ComfyUI/requirements.txt

# Optional: keep models on persistent volume (safe even if not mounted)
RUN set -eux; \
    mkdir -p /workspace/ComfyUI/models; \
    rm -rf /home/ubuntu/ComfyUI/models; \
    ln -s /workspace/ComfyUI/models /home/ubuntu/ComfyUI/models; \
    chown -R ubuntu:ubuntu /workspace /home/ubuntu

# -------------------------------
# comfyui-nunchaku (latest)
# - plugin repo (custom_nodes): nunchaku-ai/ComfyUI-nunchaku
# - backend engine wheel is installed via workflow; we just ship the workflow
# -------------------------------
RUN set -eux; \
    mkdir -p /home/ubuntu/ComfyUI/custom_nodes; \
    git clone --depth=1 https://github.com/nunchaku-ai/ComfyUI-nunchaku.git \
      /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku; \
    chown -R ubuntu:ubuntu /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku; \
    if [ -f /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt ]; then \
      python3 -m pip install --no-cache-dir -r /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt; \
    fi; \
    mkdir -p /home/ubuntu/ComfyUI/user/default/workflows; \
    curl -fsSL "https://raw.githubusercontent.com/nunchaku-ai/ComfyUI-nunchaku/main/example_workflows/install_wheel.json" \
      -o /home/ubuntu/ComfyUI/user/default/workflows/install_wheel.json || true; \
    chown -R ubuntu:ubuntu /home/ubuntu/ComfyUI/user

# -------------------------------
# Branding (keep!)
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh (must not change) (keep!)
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# post_start.sh — only starts ComfyUI, logs to CONSOLE ONLY
# start.sh will execute /post_start.sh automatically (as you saw in trace)
# -------------------------------
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

HOST="${COMFYUI_HOST:-0.0.0.0}"
PORT="${COMFYUI_PORT:-8188}"
EXTRA_ARGS="${COMFYUI_EXTRA_ARGS:-}"

# Locate ComfyUI (compatible with your env)
if [ -d "/home/ubuntu/ComfyUI" ]; then
  COMFY_DIR="/home/ubuntu/ComfyUI"
elif [ -d "/opt/ComfyUI" ]; then
  COMFY_DIR="/opt/ComfyUI"
else
  echo "[post_start] ERROR: ComfyUI directory not found." >&2
  exit 1
fi

echo "[post_start] Starting ComfyUI (console-only logs)"
echo "[post_start] dir=${COMFY_DIR}"
echo "[post_start] listen=${HOST} port=${PORT} extra='${EXTRA_ARGS}'"

# Keep logs on stdout/stderr for collectors.
# Background the process so start.sh can continue its own flow.
(
  exec sudo -u ubuntu bash -lc "
    cd \"${COMFY_DIR}\" && \
    exec python3 -u main.py \
      --listen \"${HOST}\" \
      --port   \"${PORT}\" \
      ${EXTRA_ARGS}
  "
) &

echo "[post_start] ComfyUI launch submitted. GUI: http://${HOST}:${PORT}"
EOS

RUN chmod +x /post_start.sh

EXPOSE 22 8888 8188

# IMPORTANT: do NOT switch USER; start.sh needs root privileges.
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
