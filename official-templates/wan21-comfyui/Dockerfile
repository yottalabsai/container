# ---- 基座参数（可覆盖）----
ARG BASE_IMAGE_AMD64="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
# 如无 NGC 拉取权限，可改为公开 CUDA 镜像（但 arm64 上的 PyTorch CUDA 轮子自行处理）
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

# 为了根据架构切换，先把两种基座都起一个阶段
FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

# 由 Buildx 注入的目标架构：amd64 / arm64
ARG TARGETARCH
# 选择对应基座作为真正的起点
FROM base_${TARGETARCH} AS base

# ---- 通用构建参数 ----
ARG PYTHON_VERSION="3.11"
ARG COMFYUI_PORT="8188"
ARG UBUNTU_USER=ubuntu

# 可选：安装 Nunchaku
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

SHELL ["/bin/bash","-o","pipefail","-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1

# -----------------------------------------
# 系统依赖
# -----------------------------------------
# 说明：
# - 一些 arm64/NGC 基座已带 Python/conda；下方步骤做容错处理（失败不致命）。
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------
# Python 安装（若基座已有则尽量跳过/容错）
# -----------------------------------------
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && /usr/bin/python /tmp/get-pip.py || true)

# 确保 pip 可用
RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

# -----------------------------------------
# 用户与工作目录
# -----------------------------------------
RUN useradd -m -s /bin/bash ${UBUNTU_USER} || true
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# -----------------------------------------
# Python 基础包
# -----------------------------------------
RUN python -m pip install --upgrade pip wheel setuptools

# 安装 torch（仅 amd64；arm64 用 NGC 预装）
RUN if [[ "${TARGETARCH:-amd64}" == "amd64" ]]; then \
      python -m pip install --no-cache-dir --pre torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/nightly/cu126 ; \
    fi

# 打印 PyTorch 版本（任何架构都跑；没装也不报错）
RUN python - <<'PY'
import platform
try:
    import torch
    print('PyTorch:', getattr(torch, '__version__', 'N/A'), 'Arch:', platform.machine())
except Exception as e:
    print('NOTE: torch 未可用；若为 arm64 请用 NGC 预装基座。', e)
PY

# -----------------------------------------
# 安装 ComfyUI + 常用节点
# -----------------------------------------
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install -r requirements.txt

# ComfyUI-Manager（常用管理器）
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git

# -----------------------------------------
# 可选安装 Nunchaku
# -----------------------------------------
RUN if [[ "${INSTALL_NUNCHAKU}" == "true" ]]; then \
      if [[ -z "${NUNCHAKU_REPO}" ]]; then \
        echo "[ERROR] INSTALL_NUNCHAKU=true 但未提供 NUNCHAKU_REPO" && exit 2; \
      fi; \
      cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
      if [[ -n "${NUNCHAKU_REF}" ]]; then \
        git clone --branch "${NUNCHAKU_REF}" --depth=1 "${NUNCHAKU_REPO}" ComfyUI-Nunchaku; \
      else \
        git clone --depth=1 "${NUNCHAKU_REPO}" ComfyUI-Nunchaku; \
      fi; \
      if [[ -f /home/${UBUNTU_USER}/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt ]]; then \
        python -m pip install -r /home/${UBUNTU_USER}/ComfyUI/custom_nodes/ComfyUI-Nunchaku/requirements.txt; \
      fi; \
    fi

# -----------------------------------------
# 目录结构与元数据
# -----------------------------------------
RUN mkdir -p /home/${UBUNTU_USER}/models/ckpt \
             /home/${UBUNTU_USER}/models/vae \
             /home/${UBUNTU_USER}/models/lora \
             /home/${UBUNTU_USER}/models/clip \
             /home/${UBUNTU_USER}/ComfyUI/input \
             /home/${UBUNTU_USER}/output

# 提示性挂载点（元数据，不会自动绑定宿主机）
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]

# 暴露端口（元数据，不做端口映射）
EXPOSE ${COMFYUI_PORT}

# -----------------------------------------
# 启动命令
# -----------------------------------------
CMD ["bash","-lc","cd ~/ComfyUI && \
  python main.py \
    --listen 0.0.0.0 \
    --port ${COMFYUI_PORT} \
    --output-directory ~/output \
    --extra-model-paths ~/models"]
