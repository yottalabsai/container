# ==============================
# AI-Toolkit Base Build Arguments
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG AITK_PORT="8675"

# Torch / CUDA
ARG TORCH_CHANNEL="stable"
ARG TORCH_VERSION="2.7.0"
ARG TORCH_VISION_VERSION="0.22.0"
ARG TORCH_CUDA="cu126"
ARG TORCH_NIGHTLY_INDEX_URL="https://download.pytorch.org/whl/nightly"

# ==============================
# Base OS Layer
# ==============================
# hadolint ignore=DL3006
FROM ${BASE_IMAGE} AS base
ARG PYTHON_VERSION
ARG UBUNTU_USER

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV \
  DEBIAN_FRONTEND=noninteractive \
  TZ=UTC \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  PIP_NO_CACHE_DIR=1 \
  PYTHONUNBUFFERED=1 \
  TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" \
  HF_HOME="/home/${UBUNTU_USER}/.cache/huggingface"

# Base dependencies + non-interactive tzdata configuration
# hadolint ignore=DL3008
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates \
      build-essential pkg-config ninja-build tzdata \
      ffmpeg libgl1 libglib2.0-0 \
      nginx \
      openssh-server openssh-client \
      sudo tmux vim zsh zip unzip less procps net-tools htop \
      software-properties-common dirmngr gnupg locales && \
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

# user
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    usermod -aG sudo "${UBUNTU_USER}"

# SSH
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd

# Python installation
# hadolint ignore=DL3008,DL3015
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y \
      "python${PYTHON_VERSION}" \
      "python${PYTHON_VERSION}-dev" \
      "python${PYTHON_VERSION}-venv" && \
    rm -rf /var/lib/apt/lists/*

# Unified python / pip
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    python -m pip --version

# ==============================
# python-env: Torch + Jupyter + Node
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_CHANNEL
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG TORCH_CUDA
ARG TORCH_NIGHTLY_INDEX_URL

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# Install torch first (requirements depend on it)
# hadolint ignore=DL3013,SC3010
RUN python -m pip install --upgrade pip wheel setuptools && \
    if [[ "${TORCH_CHANNEL}" == "nightly" ]]; then \
       echo "[Torch] using nightly channel"; \
       python -m pip install --no-cache-dir --pre \
         torch torchvision torchaudio \
         --index-url "${TORCH_NIGHTLY_INDEX_URL}/${TORCH_CUDA}"; \
    else \
       echo "[Torch] using stable ${TORCH_VERSION} (${TORCH_CUDA})"; \
       python -m pip install --no-cache-dir \
         "torch==${TORCH_VERSION}" \
         "torchvision==${TORCH_VISION_VERSION}" \
         "torchaudio==${TORCH_VERSION}" \
         --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"; \
    fi

# Jupyter (used with start.sh)
# hadolint ignore=DL3013
RUN python -m pip install --no-cache-dir \
      "jupyterlab>=4.0.0" \
      "notebook" \
      "ipykernel"

# Node.js 23
USER root
WORKDIR /tmp
# hadolint ignore=DL3008,DL3015
RUN curl -sL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh && \
    bash nodesource_setup.sh && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* /tmp/nodesource_setup.sh

# Verify environment
USER ${UBUNTU_USER}
RUN python - <<'PY'
import torch, platform
print("Torch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("Arch:", platform.machine())
PY

# ==============================
# aitk-builder layer
# ==============================
FROM python-env AS aitk-builder

ARG UBUNTU_USER
WORKDIR /home/${UBUNTU_USER}
USER ${UBUNTU_USER}

# Key step: clone repo, patch requirements before install to avoid pip resolution depth issues
# hadolint ignore=DL3003
RUN git clone --depth=1 https://github.com/ostris/ai-toolkit.git && \
    cd ai-toolkit && \
    # 1) Remove easy_dwpose: it pulls in onnxruntime and complex dependencies
    sed -i '/easy_dwpose/d' requirements.txt && \
    # 2) Pin versions of packages known to cause deep backtracking (based on community practice)
    printf '\nscipy==1.16.0\n'                >> requirements.txt && \
    printf 'tifffile==2025.6.11\n'           >> requirements.txt && \
    printf 'imageio==2.37.0\n'               >> requirements.txt && \
    printf 'scikit_image==0.25.2\n'          >> requirements.txt && \
    printf 'clean_fid==0.1.35\n'             >> requirements.txt && \
    printf 'pywavelets==1.9.0\n'            >> requirements.txt && \
    printf 'contourpy==1.3.3\n'             >> requirements.txt && \
    printf 'opencv_python_headless==4.11.0.86\n' >> requirements.txt && \
    # 3) Install requirements (resolver no longer explodes)
    python -m pip install --no-cache-dir -r requirements.txt && \
    cd ui && npm install

# Install some general tools as root
# hadolint ignore=DL3002
USER root
# hadolint ignore=DL3013
RUN python -m pip install --no-cache-dir \
      "huggingface_hub[cli]" \
      "GitPython>=3.1.44" \
      "toml"

# ==============================
# runtime stage
# ==============================
FROM aitk-builder AS runtime

ARG UBUNTU_USER
ARG AITK_PORT

ENV \
  TZ=UTC \
  AITK_PORT=${AITK_PORT} \
  HF_HOME="/data/huggingface" \
  DATABASE_URL="file:/data/ai-toolkit/database/aitk_db.db"

# hadolint ignore=DL3002
USER root
WORKDIR /home/${UBUNTU_USER}

# ====== Startup script ======
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/ai-toolkit-ui.log
ROOT=/home/ubuntu/ai-toolkit

mkdir -p /data/ai-toolkit/database
chown -R ubuntu:ubuntu /data

# Start UI (with port & host)
sudo -u ubuntu bash -lc "
  cd \"${ROOT}/ui\" && \
  npm run update_db || true && \
  npm run build_and_start \
    -- --host 0.0.0.0 --port \"${AITK_PORT:-8675}\" \
  >> \"${LOG}\" 2>&1 &
"

echo "[entry] AI-Toolkit UI started on 0.0.0.0:${AITK_PORT:-8675}"
EOS

# ====== Branding ======
# hadolint ignore=SC2028
RUN chmod +x /post_start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nDocs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# Entrypoint & branding
# hadolint ignore=DL3022
COPY --from=scripts start.sh /start.sh
# hadolint ignore=DL3022
COPY --from=logo yotta.txt /etc/yotta.txt
COPY README.md /usr/share/nginx/html/README.md

RUN chmod +x /start.sh

# Data volume
VOLUME ["/data"]

# Expose ports
EXPOSE 22
EXPOSE ${AITK_PORT}
EXPOSE 80

ENTRYPOINT ["/start.sh"]
