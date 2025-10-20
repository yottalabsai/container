# =========================================
# Dockerfile — FLUX-1.dev / ComfyUI (Multi-Arch)
# 支持 amd64 / arm64；可选安装 Nunchaku；默认端口 :8188
# 构建参数（可 --build-arg 覆盖）：
#   BASE_IMAGE_AMD64  nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04
#   BASE_IMAGE_ARM64  nvcr.io/nvidia/pytorch:24.10-py3  (NGC 预装 PyTorch，arm64 更稳)
#   PYTHON_VERSION    3.11
#   COMFYUI_PORT      8188
#   INSTALL_NUNCHAKU  "true"/"false"（默认 "false"）
#   NUNCHAKU_REPO     Nunchaku 仓库 URL（默认官方）
#   NUNCHAKU_REF      分支/Tag（默认 main）
# =========================================

ARG BASE_IMAGE_AMD64="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

ARG PYTHON_VERSION="3.11"
ARG COMFYUI_PORT="8188"
ARG UBUNTU_USER=ubuntu

# 可选组件：Nunchaku
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO="https://github.com/nunchaku-tech/ComfyUI-nunchaku.git"
ARG NUNCHAKU_REF="main"

SHELL ["/bin/bash","-o","pipefail","-c"]
ENV DEBIAN_FRONTEND=noninteractive PIP_NO_CACHE_DIR=1

# 1) OS 依赖
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 software-properties-common && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    rm -rf /var/lib/apt/lists/*

# 2) Python（容错：基座已有也能跳过）
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && /usr/bin/python /tmp/get-pip.py || true)
RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)
RUN python -m pip install --upgrade pip wheel setuptools

# 3) PyTorch（amd64: 安装夜版 cu128；arm64: 依赖 NGC 预装）
RUN if [[ "${TARGETARCH}" == "amd64" ]]; then \
      python -m pip install torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu128 ; \
    fi && \
    python -c "import platform; \
try:
 import torch; print('PyTorch:', torch.__version__, 'Arch:', platform.machine())
except Exception as e:
 print('NOTE: torch 未可用；若为 arm64 请用 NGC 预装基座。', e)"

# 4) 安装 ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && python -m pip install -r requirements.txt

# 5) 常用节点：ComfyUI-Manager
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git

# （可选）如果你后续确认 FLUX-1.dev 的专用节点仓库，可在此处追加：
# RUN cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
#     git clone --depth=1 https://github.com/<org>/ComfyUI-FLUX1dev-Nodes.git

# 6) 可选：安装 Nunchaku
RUN if [[ "${INSTALL_NUNCHAKU}" == "true" ]]; then \
      cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
      git clone --depth=1 -b "${NUNCHAKU_REF}" "${NUNCHAKU_REPO}" ComfyUI-Nunchaku && \
      if [[ -f ComfyUI-Nunchaku/requirements.txt ]]; then \
        python -m pip install -r ComfyUI-Nunchaku/requirements.txt; \
      fi; \
    fi

# 7) 目录与元数据
RUN useradd -m -s /bin/bash ${UBUNTU_USER} || true && \
    mkdir -p /home/${UBUNTU_USER}/models/ckpt \
             /home/${UBUNTU_USER}/models/vae \
             /home/${UBUNTU_USER}/models/lora \
             /home/${UBUNTU_USER}/models/clip \
             /home/${UBUNTU_USER}/ComfyUI/input \
             /home/${UBUNTU_USER}/output
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]
EXPOSE ${COMFYUI_PORT}

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# 8) 启动
CMD ["bash","-lc","cd ~/ComfyUI && \
  python main.py \
    --listen 0.0.0.0 \
    --port ${COMFYUI_PORT} \
    --output-directory ~/output \
    --extra-model-paths ~/models"]
