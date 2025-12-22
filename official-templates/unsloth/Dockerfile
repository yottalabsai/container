# ==============================
# Unsloth LLM Fine-tuning 基座构建参数
# 带 CUDA + PyTorch + Unsloth
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.1.0-cudnn-runtime-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"

# Torch / CUDA 相关参数（由 bake 覆盖）
ARG TORCH_VERSION="2.4.1"
ARG TORCH_CUDA="cu121"
ARG TORCH_INDEX_URL="https://download.pytorch.org/whl/cu121"

# ==============================
# base: CUDA + 系统依赖 + Python
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
    PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" \
    HF_HOME="/home/${UBUNTU_USER}/.cache/huggingface"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      software-properties-common \
      sudo \
      tmux vim zsh zip unzip less procps net-tools htop && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && update-locale && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 创建普通用户 + HF 缓存目录
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh && \
    mkdir -p "${HF_HOME}" && chown -R ${UBUNTU_USER}:${UBUNTU_USER} "${HF_HOME}"

# 安装指定版本 Python + pip（参考 Wan2.2 的 deadsnakes 方案）
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
# python-env: 安装 PyTorch + Unsloth
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_VERSION
ARG TORCH_CUDA
ARG TORCH_INDEX_URL

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# 创建 venv
RUN python -m venv /opt/venv
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

# 基础 python 工具链
RUN python -m pip install --upgrade pip wheel setuptools && \
    echo "[Torch] Using ${TORCH_VERSION} (${TORCH_CUDA}) from ${TORCH_INDEX_URL}" && \
    python -m pip install --no-cache-dir \
      "torch==${TORCH_VERSION}" \
      "torchvision" \
      "torchaudio" \
      --index-url "${TORCH_INDEX_URL}"

# 安装 Unsloth 及常用 LLM 生态依赖
RUN python -m pip install --no-cache-dir \
      "unsloth[all]" \
      "transformers" \
      "datasets" \
      "accelerate" \
      "bitsandbytes" \
      "trl" \
      "peft"

# 可选：装个 jupyter，方便用这个镜像做 notebook 开发
RUN python -m pip install --no-cache-dir \
      "jupyterlab>=4.0.0" \
      "notebook" \
      "ipykernel"

# 简单环境自检
RUN python - <<'PY'
import torch, platform
print("[Unsloth] Python env check")
print("  PyTorch:", torch.__version__)
print("  CUDA available:", torch.cuda.is_available())
print("  Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("  Arch:", platform.machine())
PY

# ==============================
# runtime: 工具 + Branding + 启动体验
# ==============================
FROM python-env AS runtime

ARG UBUNTU_USER

USER root
WORKDIR /home/${UBUNTU_USER}

# 小工具：htop / nano / jq / tree / ping 等
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      htop \
      nano \
      iputils-ping \
      lsof \
      tree \
      jq \
      net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# start.sh：默认启动交互 shell
RUN cat >/start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth] welcome."

# 自动激活 venv
if [ -f "/opt/venv/bin/activate" ]; then
  source /opt/venv/bin/activate
fi

echo
echo "========================="
echo "  Unsloth Training Shell "
echo "========================="
echo
echo "Examples:"
echo "  python - <<'PY'"
echo "  from unsloth import is_good"
echo "  print('Unsloth is good? ->', is_good())"
echo "  PY"
echo

bash
EOS

# post_start.sh：容器启动信息（预留给上层 orchestrator 调用）
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth] container started"

echo "[INFO] Python: $(python --version)"
echo "[INFO] Torch:  $(python - <<'P'
import torch
print(torch.__version__)
P
)"
echo "[INFO] CUDA available: $(python - <<'P'
import torch
print(torch.cuda.is_available())
P
)"
EOS

# Branding: yotta 文案 + docs 提示
RUN echo "YottaLabs AI - Unsloth Training Platform" > /etc/yotta.txt

RUN chmod +x /post_start.sh /start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# /yotta 工具目录
RUN mkdir -p /yotta/tools && \
    echo "#!/usr/bin/env bash" > /yotta/tools/info.sh && \
    echo "echo '[Yotta] GPU:'; nvidia-smi || true" >> /yotta/tools/info.sh && \
    echo "echo '[Yotta] Python:'; python -V" >> /yotta/tools/info.sh && \
    chmod +x /yotta/tools/info.sh && \
    ln -s /yotta/tools/info.sh /usr/local/bin/yotta-info

ENV PATH="/yotta/tools:${PATH}"

# 全局 shell 欢迎语
RUN echo '' >> /etc/bash.bashrc && \
    echo 'echo -e "\033[1;35mWelcome to Yotta Unsloth Training Environment!\033[0m"' >> /etc/bash.bashrc && \
    echo 'echo -e "Type: \033[1;36myotta-info\033[0m for quick system info."' >> /etc/bash.bashrc

# HF 缓存环境变量（用户态）
ENV HF_HOME="/home/${UBUNTU_USER}/.cache/huggingface" \
    TRANSFORMERS_CACHE="${HF_HOME}/transformers" \
    HF_DATASETS_CACHE="${HF_HOME}/datasets" \
    HUGGINGFACE_HUB_TOKEN=""

# 切回普通用户
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

# 默认启动：进入带 venv 的 shell
CMD ["/start.sh"]
