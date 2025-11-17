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
ARG TORCH_VERSION="2.4.0"
ARG TORCH_CUDA="cu124"  # 对应 https://download.pytorch.org/whl/${TORCH_CUDA}

# ==============================
# Base: CUDA + 系统依赖 + Python
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

# ---- 系统依赖：含 nginx / tmux / vim / zip / zsh ----
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      nginx \
      tmux vim zip zsh less procps \
    && git lfs install \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# 确保有 pip
RUN python -m pip --version || (ln -sf /usr/bin/python3 /usr/bin/python && python -m ensurepip)

# 创建业务用户（避免 root 跑服务）
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true

# ==============================
# Python-env: torch + 基础 pip
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_VERSION
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
      "torchvision==${TORCH_VERSION}" \
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
FROM base AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

# --------- Nginx / README / logo（来自额外 build context）---------
# 这些 context 由 buildx bake 通过 contexts 传入：
#   proxy -> ../../container-template/proxy
#   logo  -> ../../container-template
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt

# 小彩蛋：登录 root shell 时显示品牌信息（保留你之前的逻辑）
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# 拷贝业务用户 HOME（ComfyUI + 模型目录）
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

COPY --chown=${UBUNTU_USER}:${UBUNTU_USER} \
  --from=comfy-builder /home/${UBUNTU_USER} /home/${UBUNTU_USER}

# 对外挂载点 & 端口
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]
EXPOSE 80
EXPOSE ${COMFYUI_PORT}

# 同时启动 Nginx + ComfyUI
CMD ["bash","-lc","nginx && \
  python ComfyUI/main.py \
    --listen 0.0.0.0 \
    --port ${COMFYUI_PORT} \
    --output-directory /home/${UBUNTU_USER}/output \
    --extra-model-paths /home/${UBUNTU_USER}/models"]
