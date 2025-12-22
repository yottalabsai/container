# ==============================
# AI-Toolkit Base 构建参数
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
FROM ${BASE_IMAGE} AS base
ARG PYTHON_VERSION
ARG UBUNTU_USER

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV \
 TZ=UTC \
 DEBIAN_FRONTEND=noninteractive \
 LANG=C.UTF-8 \
 LC_ALL=C.UTF-8 \
 PIP_NO_CACHE_DIR=1 \
 PYTHONUNBUFFERED=1 \
 TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" \
 HF_HOME="/home/${UBUNTU_USER}/.cache/huggingface"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates \
      build-essential pkg-config ninja-build tzdata \
      ffmpeg libgl1 libglib2.0-0 \
      nginx \
      openssh-server openssh-client \
      sudo tmux vim zsh zip unzip less procps net-tools htop \
      software-properties-common dirmngr gnupg && \
    # 设置时区为 UTC，避免 tzdata 交互
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    git lfs install && \
    rm -rf /var/lib/apt/lists/*

# user
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd

# locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    apt-get update -y && apt-get install -y --no-install-recommends locales && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

# SSH
RUN sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    mkdir -p /var/run/sshd

# Python 安装
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" \
      "python${PYTHON_VERSION}-dev" \
      "python${PYTHON_VERSION}-venv" && \
    rm -rf /var/lib/apt/lists/*

# 这里重点：同时创建 python3 和 python 软链
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python3 /tmp/get-pip.py && rm -f /tmp/get-pip.py


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

RUN python -m pip install --upgrade pip wheel setuptools && \
    if [[ "${TORCH_CHANNEL}" == "nightly" ]]; then \
       python -m pip install --no-cache-dir --pre torch torchvision torchaudio \
         --index-url "${TORCH_NIGHTLY_INDEX_URL}/${TORCH_CUDA}"; \
    else \
       python -m pip install --no-cache-dir \
         "torch==${TORCH_VERSION}" \
         "torchvision==${TORCH_VISION_VERSION}" \
         "torchaudio==${TORCH_VERSION}" \
         --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"; \
    fi

RUN python -m pip install --no-cache-dir jupyterlab notebook ipykernel

# Node.js 23
USER root
WORKDIR /tmp
RUN curl -sL https://deb.nodesource.com/setup_23.x -o node.sh && \
    bash node.sh && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# 检查
USER ${UBUNTU_USER}
RUN python - <<'PY'
import torch
print("Torch:", torch.__version__)
print("CUDA:", torch.cuda.is_available())
PY


# ==============================
# aitk-builder layer
# ==============================
FROM python-env AS aitk-builder

ARG UBUNTU_USER
WORKDIR /home/${UBUNTU_USER}
USER ${UBUNTU_USER}

RUN git clone --depth=1 https://github.com/ostris/ai-toolkit.git && \
    cd ai-toolkit && \
    python -m pip install --no-cache-dir -r requirements.txt && \
    cd ui && npm install

USER root
RUN python -m pip install --no-cache-dir \
      "huggingface_hub[cli]" \
      "GitPython>=3.1.44" \
      toml


# ==============================
# runtime stage
# ==============================
FROM aitk-builder AS runtime

ARG UBUNTU_USER
ARG AITK_PORT

ENV \
 AITK_PORT=${AITK_PORT} \
 HF_HOME="/data/huggingface" \
 DATABASE_URL="file:/data/ai-toolkit/database/aitk_db.db"

USER root
WORKDIR /home/${UBUNTU_USER}

# start script
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/ai-toolkit-ui.log
ROOT=/home/ubuntu/ai-toolkit

mkdir -p /data/ai-toolkit/database
chown -R ubuntu:ubuntu /data

sudo -u ubuntu bash -lc "
 cd /home/ubuntu/ai-toolkit/ui && \
 npm install && \
 npm run update_db || true && \
 npm run build_and_start \
   -- --host 0.0.0.0 --port \"${AITK_PORT:-8675}\" \
 >> \"$LOG\" 2>&1 &
"
echo "[entry] AI-Toolkit ready."
EOS

# ====== 商业化元素 ======
RUN chmod +x /post_start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e \"\nDocs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n\"' >> /root/.bashrc

# runtime entry
COPY --from=scripts start.sh /start.sh
COPY --from=logo yotta.txt /etc/yotta.txt
COPY README.md /usr/share/nginx/html/README.md

RUN chmod +x /start.sh

# runtime volume
VOLUME ["/data"]

EXPOSE 22
EXPOSE ${AITK_PORT}
EXPOSE 80

ENTRYPOINT ["/start.sh"]
