# =========================================
# Dockerfile.comfyui — WAN 2.1 ComfyUI 镜像
# 基座：CUDA 12.8.1 + cuDNN + Ubuntu 22.04 + Python 3.11
# =========================================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG UBUNTU_USER=ubuntu
ARG PYTHON_VERSION="3.11"
ARG COMFYUI_PORT="8188"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ---------- OS 基础依赖 ----------
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      openssh-client \
      software-properties-common && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    rm -rf /var/lib/apt/lists/*

# ---------- Python 3.11 & pip ----------
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    /usr/bin/python /tmp/get-pip.py && rm -f /tmp/get-pip.py

# ---------- 用户与工作目录 ----------
RUN useradd -m -s /bin/bash ${UBUNTU_USER}
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# ---------- PyTorch/cu128 ----------
# 你也可以切到稳定版（把 index-url 删掉并按 CUDA 匹配官方轮子）
RUN python -m pip install --no-cache-dir --upgrade pip wheel setuptools && \
    python -m pip install --no-cache-dir \
      torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# ---------- 安装 ComfyUI ----------
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install --no-cache-dir -r requirements.txt

# ---------- 常用自定义节点（可按需增删） ----------
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git

# 预留：WAN 2.1/2.2 相关节点（等你确认具体 repo 后可直接添加）
# RUN cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
#     git clone --depth=1 https://github.com/your-org/ComfyUI-Wan2-Nodes.git

# ---------- 模型/输出目录 ----------
RUN mkdir -p /home/${UBUNTU_USER}/models/ckpt \
             /home/${UBUNTU_USER}/models/vae \
             /home/${UBUNTU_USER}/models/lora \
             /home/${UBUNTU_USER}/models/clip \
             /home/${UBUNTU_USER}/ComfyUI/input \
             /home/${UBUNTU_USER}/output

# ---------- 暴露端口 ----------
EXPOSE ${COMFYUI_PORT}

# ---------- 默认启动 ----------
# --listen 0.0.0.0 对外服务；--output-directory 指定输出；--extra-model-paths 统一模型目录
CMD ["bash","-lc","cd ~/ComfyUI && \
  python main.py \
    --listen 0.0.0.0 \
    --port ${COMFYUI_PORT} \
    --output-directory ~/output \
    --extra-model-paths ~/models"]
