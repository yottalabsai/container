# ===============================
# comfyui-nunchaku (FULL, CLEAN)
# - container/container-template is immutable
# - this image only customizes within official-templates/comfyui-nunchaku
# ===============================

ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
# PyTorch wheels must match CUDA in BASE_IMAGE (cu128 for CUDA 12.8.x)
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH

# -------------------------------
# System deps + tools
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs \
      sudo openssh-server nginx tini \
      build-essential make g++ pkg-config \
      software-properties-common \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      acl bash tzdata locales \
      ffmpeg \
      libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    ; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; locale-gen; update-locale; \
    mkdir -p /run/sshd; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Python (deadsnakes) + pip
# -------------------------------
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python${PYTHON_VERSION} \
      python${PYTHON_VERSION}-dev \
      python${PYTHON_VERSION}-venv \
      python${PYTHON_VERSION}-distutils \
    ; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
    python3 /tmp/get-pip.py; \
    rm -f /tmp/get-pip.py; \
    python3 -m pip install -U pip setuptools wheel; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Torch
# -------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir ${TORCH}

# -------------------------------
# Python deps (ComfyUI + video stacks)
# NOTE: start.sh may launch JupyterLab via python3.11 -m jupyter
# -------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U \
      pillow aiohttp \
      opencv-python-headless \
      matplotlib scikit-image \
      accelerate safetensors \
      imageio imageio-ffmpeg \
      numba llvmlite \
      gguf lark \
      jupyterlab \
      "huggingface_hub>=0.26,<1.0" \
      "diffusers>=0.30,<1.0" \
      "transformers>=4.41,<5.0"

# -------------------------------
# ubuntu user (ComfyUI runtime)
# -------------------------------
RUN set -eux; \
    useradd -ms /bin/bash ubuntu; \
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/90-ubuntu; \
    chmod 0440 /etc/sudoers.d/90-ubuntu

# -------------------------------
# ComfyUI
# -------------------------------
RUN set -eux; \
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /home/ubuntu/ComfyUI; \
    chown -R ubuntu:ubuntu /home/ubuntu/ComfyUI; \
    python3 -m pip install --no-cache-dir -r /home/ubuntu/ComfyUI/requirements.txt

# -------------------------------
# ComfyUI-Nunchaku (custom_nodes)
# -------------------------------
RUN set -eux; \
    git clone --depth=1 https://github.com/nunchaku-ai/ComfyUI-Nunchaku.git \
      /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku; \
    chown -R ubuntu:ubuntu /home/ubuntu/ComfyUI/custom_nodes/ComfyUI-Nunchaku

# -------------------------------
# Branding (from immutable container-template context)
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh (immutable, must keep)
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# comfyui-nunchaku runtime scripts (this template only)
# -------------------------------
COPY boot.sh /boot.sh
COPY post_start.sh /post_start.sh
RUN chmod 755 /boot.sh /post_start.sh

EXPOSE 22 8888 8188

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
