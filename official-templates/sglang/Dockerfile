# ==============================
# Global build args
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
# GPU 架构：5090=100, 4090=89, H100=90
ARG GPU_ARCH="100"

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
    TZ=UTC \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# ---- 核心系统依赖 + SSH + 常用工具 ----
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      libnuma-dev \
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

# ---- 创建非 root 用户 ----
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true
RUN echo "${UBUNTU_USER}:ubuntu" | chpasswd
RUN mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh

# SSH config
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# ---- Python 环境安装 ----
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
# Build: 安装 PyTorch + sgl-kernel + sglang
# ==============================
FROM base AS build

ARG PYTHON_VERSION
ARG GPU_ARCH

ENV TORCH_CUDA_ARCH_LIST="${GPU_ARCH}" \
    CMAKE_CUDA_ARCHITECTURES="${GPU_ARCH}"

# 安装 PyTorch (cu121)
RUN python -m pip install --no-cache-dir \
    torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
    --index-url https://download.pytorch.org/whl/cu121

# 安装预编译好的 sgl-kernel（CUDA 12.1+ 只需要这一步）
RUN python -m pip install --no-cache-dir "sgl-kernel>=0.3.8"

# 安装 SGLang Runtime
RUN python -m pip install --no-cache-dir "sglang[all]"

# 运行时依赖
RUN python -m pip install --no-cache-dir \
    "transformers>=4.40,<5" \
    huggingface_hub \
    sentencepiece \
    fastapi uvicorn uvloop orjson \
    hf_transfer

# ==============================
# Final: 运行时镜像（带 Qwen + 进入容器提示）
# ==============================
FROM base AS final

ARG PYTHON_VERSION
ARG UBUNTU_USER

ENV HF_HOME=/workspace/hf \
    SGLANG_MODEL="Qwen/Qwen2.5-3B-Instruct" \
    SGLANG_HOST="0.0.0.0" \
    SGLANG_PORT="30000"

# 工作目录 & HF cache
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# 拷贝 Python 依赖（从 build）
COPY --from=build /usr/local/lib/python${PYTHON_VERSION} /usr/local/lib/python${PYTHON_VERSION}
COPY --from=build /usr/local/bin /usr/local/bin

# ==============================
# Branding：进入容器提示
# ==============================
RUN echo "\
--------------------------------------------------\n\
   Welcome to YottaLabs GPU Runtime\n\
   Powered by SGLang + Qwen\n\
--------------------------------------------------\n\
" > /etc/yotta.txt

# root 登录提示
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nDocs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ubuntu 用户登录提示
RUN echo 'cat /etc/yotta.txt' >> /home/${UBUNTU_USER}/.bashrc && \
    echo 'echo -e "\nDocs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /home/${UBUNTU_USER}/.bashrc && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.bashrc

# ==============================
# 启动脚本：SGLang + Qwen
# ==============================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

MODEL="${SGLANG_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
HOST="${SGLANG_HOST:-0.0.0.0}"
PORT="${SGLANG_PORT:-30000}"

echo "[SGLang] Model : ${MODEL}"
echo "[SGLang] Host  : ${HOST}"
echo "[SGLang] Port  : ${PORT}"

# 按需下载模型（懒加载，由 sglang 自己通过 HF 拉）
# 这里不强制预拉，保证镜像是“空模型”商业化交付形态

exec uvicorn sglang.api.server:app \
  --host "${HOST}" \
  --port "${PORT}"
EOF

RUN chmod +x /start.sh

EXPOSE 22 30000

# 入口：启动 sshd + sglang
CMD ["/bin/bash","-lc","service ssh start && /start.sh"]
