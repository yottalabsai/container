# syntax=docker/dockerfile:1.7-labs

# ==============================
# Flux1-Dev ComfyUI 基座构建参数
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# 是否安装 Nunchaku（Flux 默认：否，但 bake 可覆盖）
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

ARG TORCH_VERSION="2.4.0"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu124"

# ==============================
# Base 层：CUDA + Python + SSH + 工具
# ==============================
FROM ${BASE_IMAGE} AS base

ARG PYTHON_VERSION
ARG UBUNTU_USER

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx openssh-server openssh-client \
      tmux vim zsh zip unzip less procps net-tools htop \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true
RUN echo "${UBUNTU_USER}:ubuntu" | chpasswd

RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

RUN mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# Python 安装
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && python3 /tmp/get-pip.py || true)

# ==============================
# Python + torch
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG TORCH_CUDA

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

RUN python3 -m pip install --upgrade pip wheel setuptools

RUN python3 -m pip install \
      torch==${TORCH_VERSION} \
      torchvision==${TORCH_VISION_VERSION} \
      torchaudio==${TORCH_VERSION} \
      --index-url https://download.pytorch.org/whl/${TORCH_CUDA}

# ==============================
# ComfyUI + Manager + 可选 Nunchaku
# ==============================
FROM python-env AS comfy-builder

ARG UBUNTU_USER
ARG INSTALL_NUNCHAKU
ARG NUNCHAKU_REPO
ARG NUNCHAKU_REF

WORKDIR /home/${UBUNTU_USER}

RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && python3 -m pip install -r requirements.txt

RUN mkdir -p ComfyUI/custom_nodes && \
    cd ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git

RUN if [[ "${INSTALL_NUNCHAKU}" == "true" ]]; then \
      cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
      git clone --depth=1 ${NUNCHAKU_REPO} ComfyUI-Nunchaku && \
      if [[ -f ComfyUI-Nunchaku/requirements.txt ]]; then \
        python3 -m pip install -r ComfyUI-Nunchaku/requirements.txt; \
      fi; \
    fi

RUN mkdir -p \
      models/ckpt models/vae models/lora models/clip \
      ComfyUI/input \
      output

# ==============================
# Runtime 层：Nginx + SSH + ComfyUI
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/
COPY README.md /usr/share/nginx/html/

USER root
WORKDIR /home/${UBUNTU_USER}

EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

CMD ["bash","-lc","/usr/sbin/sshd && nginx && \
  su - ${UBUNTU_USER} -c \"cd ~/ComfyUI && python3 main.py \
    --listen 0.0.0.0 --port ${COMFYUI_PORT} \
    --output-directory ~/output \
    --extra-model-paths ~/models\""]
