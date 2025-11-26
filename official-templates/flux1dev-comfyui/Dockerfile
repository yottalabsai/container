# ==============================
# Flux1-Dev ComfyUI 基座构建参数
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# 是否安装 Nunchaku（默认：否，由 bake 覆盖）
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

ARG TORCH_VERSION="2.4.1"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu124"

# 是否启用 FLUX VAE 下载（默认 false）
ARG ENABLE_FLUX_VAE="true"

# HuggingFace Token（只在 ENABLE_FLUX_VAE=true 时才需要）
ARG HF_TOKEN=""

# ==============================
# Base: CUDA + 系统依赖 + Python + SSH
# ==============================
FROM ${BASE_IMAGE} AS base

ARG PYTHON_VERSION
ARG UBUNTU_USER

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx \
      openssh-server openssh-client \
      sudo \
      tmux vim zsh zip unzip less procps net-tools htop && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && update-locale && \
    mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建普通用户
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# SSH 配置：允许密码登录，但禁 root
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# 安装指定版本 Python + pip
RUN add-apt-repository ppa:deadsnakes/ppa -y || true && \
    apt-get update -y || true && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python || true && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 || true && \
    (curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      /usr/bin/python /tmp/get-pip.py || true) && \
    rm -f /tmp/get-pip.py

# 兜底：保证 python -m pip 可用
RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

# ==============================
# python-env: 安装 PyTorch
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG TORCH_CUDA
ARG COMFYUI_PORT

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

RUN python -m pip install --upgrade pip wheel setuptools && \
    python -m pip install --no-cache-dir \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCH_VISION_VERSION}" \
      "torchaudio==${TORCH_VERSION}" \
      --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"

# 简单的环境自检
RUN python - <<'PY'
import torch, platform
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("Arch:", platform.machine())
PY

# ==============================
# comfy-builder
# ==============================
FROM python-env AS comfy-builder

ARG UBUNTU_USER
ARG INSTALL_NUNCHAKU
ARG NUNCHAKU_REPO
ARG NUNCHAKU_REF

ARG ENABLE_FLUX_VAE
ARG HF_TOKEN

WORKDIR /home/${UBUNTU_USER}

# ComfyUI 本体
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install --no-cache-dir -r requirements.txt

# Manager 节点
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git ComfyUI-Manager

# 可选：Nunchaku
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
        python -m pip install --no-cache-dir -r ComfyUI-Nunchaku/requirements.txt; \
      fi; \
    fi

# 模型 & 目录结构
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output

# -------------------------------
# FLUX1-DEV 模型下载（UNet + T5 + CLIP + 可选 VAE）
# -------------------------------
RUN set -euo pipefail; \
    ROOT="/home/${UBUNTU_USER}/ComfyUI/models"; \
    mkdir -p \
      "${ROOT}/diffusion_models" \
      "${ROOT}/text_encoders" \
      "${ROOT}/vae"; \
    \
    echo "[FLUX1-DEV] Downloading UNet (flux1-dev.safetensors) from Comfy-Org ..."; \
    wget -O "${ROOT}/diffusion_models/flux1-dev.safetensors" \
      "https://huggingface.co/Comfy-Org/flux1-dev/resolve/main/flux1-dev.safetensors"; \
    \
    echo "[FLUX1-DEV] Downloading T5 XXL text encoder (fp8) ..."; \
    wget -O "${ROOT}/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors" \
      "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors"; \
    \
    echo "[FLUX1-DEV] Downloading CLIP_L text encoder ..."; \
    wget -O "${ROOT}/text_encoders/clip_l.safetensors" \
      "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"; \
    \
    if [ "${ENABLE_FLUX_VAE}" = "true" ]; then \
      echo "[FLUX1-DEV] ENABLE_FLUX_VAE=true → preparing VAE download..."; \
      if [ -z "${HF_TOKEN}" ]; then \
        echo "[FLUX1-DEV] ERROR: VAE download requires HF_TOKEN, but HF_TOKEN is empty."; \
        exit 1; \
      fi; \
      echo "[FLUX1-DEV] Downloading VAE (ae.safetensors) with HuggingFace token ..."; \
      wget --header="Authorization: Bearer ${HF_TOKEN}" \
        -O "${ROOT}/vae/ae.safetensors" \
        "https://huggingface.co/comfyanonymous/flux_vae/resolve/main/ae.safetensors"; \
    else \
      echo "[FLUX1-DEV] ENABLE_FLUX_VAE=false → skipping VAE download."; \
    fi; \
    \
    echo "[FLUX1-DEV] Model download stage finished."


# ==============================
# runtime
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

USER root
WORKDIR /home/${UBUNTU_USER}

# 这些来自 docker buildx bake 的额外上下文（scripts/proxy/logo）
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY README.md      /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt /etc/yotta.txt
COPY --from=scripts start.sh /start.sh

# 这里插入 post_start.sh（容器内第二阶段启动 ComfyUI）
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/comfyui.log
mkdir -p /home/ubuntu

# 以 ubuntu 用户运行 ComfyUI
sudo -u ubuntu bash -lc "
  cd /home/ubuntu/ComfyUI && \
  python -u main.py \
    --listen 0.0.0.0 \
    --port   \"${COMFYUI_PORT:-8188}\" \
  >> \"$LOG\" 2>&1 &
"

echo "ComfyUI started on 0.0.0.0:${COMFYUI_PORT:-8188}, logs: $LOG"
EOS

RUN chmod +x /post_start.sh /start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# 数据卷
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]

# 暴露端口：Nginx / ComfyUI / SSH
EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

# 健康检查：直接探 ComfyUI HTTP 端口
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${COMFYUI_PORT:-8188}/" >/dev/null || exit 1

# 入口脚本来自 scripts 上下文的 start.sh
ENTRYPOINT ["/start.sh"]
