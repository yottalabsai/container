# syntax=docker/dockerfile:1.7-labs

# ==============================
# Global build args (可在 bake 里覆盖)
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""
ARG TORCH_VERSION="2.4.1"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu124"

# ==============================
# Base: CUDA + 系统依赖 + Python + SSH + 工具
# ==============================
FROM ${BASE_IMAGE} AS base

ARG PYTHON_VERSION
ARG UBUNTU_USER

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Shanghai \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# ---- 核心系统依赖 + SSH + 常用工具 ----
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx \
      openssh-server openssh-client \
      tmux vim zsh zip unzip less procps net-tools htop \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ---- 创建非 root 用户（避免 root SSH 登录）----
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true

# ---- 给 ubuntu 用户加密码（可选，可改）----
RUN echo "${UBUNTU_USER}:ubuntu" | chpasswd

# ---- 允许 ubuntu 用户通过 SSH 登录（禁止 root 登录）----
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# ---- SSH 预处理：保持容器前台可启动 ----
RUN mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# ---- Python 安装（deadsnakes + get-pip 容错）----
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      /usr/bin/python /tmp/get-pip.py || true) && \
    rm -f /tmp/get-pip.py

RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

# ==============================
# Python-env: torch + 基础 pip
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG TORCH_CUDA
ARG COMFYUI_PORT

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# 升级基础 pip 工具
RUN python -m pip install --upgrade pip wheel setuptools

# 统一 torch 版本：2.4.x + ${TORCH_CUDA}
# 说明：虽然基座是 CUDA 12.8.1，但 cu124 轮子在 runtime 上是兼容的（同 major 12）
RUN python -m pip install --no-cache-dir \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCH_VISION_VERSION}" \
      "torchaudio==${TORCH_VERSION}" \
      --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"

# 打印版本信息，方便排查
RUN python - <<'PY'
import torch, platform
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("Arch:", platform.machine())
PY

# ==============================
# Comfy-builder: 安装 ComfyUI + Manager + 可选 Nunchaku
# ==============================
FROM python-env AS comfy-builder

ARG UBUNTU_USER
ARG INSTALL_NUNCHAKU
ARG NUNCHAKU_REPO
ARG NUNCHAKU_REF

WORKDIR /home/${UBUNTU_USER}

# 安装 ComfyUI
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install -r requirements.txt

# ComfyUI-Manager
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/ltdrdata/ComfyUI-Manager.git

# 可选安装 Nunchaku
RUN if [[ "${INSTALL_NUNCHAKU}" == "true" ]]; then \
      if [[ -z "${NUNCHAKU_REPO}" ]]; then \
        echo "[ERROR] INSTALL_NUNCHAKU=true but NUNCHAKU_REPO is empty" >&2; exit 2; \
      fi; \
      cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
      if [[ -n "${NUNCHAKU_REF}" ]]; then \
        git clone --branch "${NUNCHAKU_REF}" --depth=1 "${NUNCHAKU_REPO}" ComfyUI-Nunchaku; \
      else \
        git clone --depth=1 "${NUNCHAKU_REPO}" ComfyUI-Nunchaku; \
      fi; \
      if [[ -f ComfyUI-Nunchaku/requirements.txt ]]; then \
        python -m pip install -r ComfyUI-Nunchaku/requirements.txt; \
      fi; \
    fi

# 目录结构
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output

# ==============================
# Runtime: 仅包含运行时 + Nginx / README / logo
# ==============================

FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

# --------- Nginx / README / logo（来自额外 build context）---------
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt

RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

USER root
WORKDIR /home/${UBUNTU_USER}

VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]
EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

CMD ["bash","-lc","/usr/sbin/sshd && nginx && \
  su - ${UBUNTU_USER} -c \"cd /home/${UBUNTU_USER}/ComfyUI && \
    python main.py \
      --listen 0.0.0.0 \
      --port ${COMFYUI_PORT} \
      --output-directory /home/${UBUNTU_USER}/output \
      --extra-model-paths /home/${UBUNTU_USER}/models\""]
