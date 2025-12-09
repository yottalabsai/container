# ==============================
# Wan2.1-T2V-1.3B ComfyUI 基座构建参数
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# 是否安装 Nunchaku（默认：否，由 bake 覆盖）
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

# Torch / CUDA 相关参数
ARG TORCH_CHANNEL="nightly"
ARG TORCH_VERSION="2.4.1"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu128"
ARG TORCH_NIGHTLY_INDEX_URL="https://download.pytorch.org/whl/nightly"

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
    PYTHONUNBUFFERED=1 \
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0;12.0" \
    HF_HOME="/home/${UBUNTU_USER}/.cache/huggingface"

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
    chmod 700 /home/${UBUNTU_USER}/.ssh && \
    mkdir -p "${HF_HOME}" && chown -R ${UBUNTU_USER}:${UBUNTU_USER} "${HF_HOME}"

# SSH 配置
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# 安装 Python
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
# python-env: 安装 PyTorch
# ==============================
FROM base AS python-env

ARG UBUNTU_USER
ARG TORCH_CHANNEL
ARG TORCH_VERSION
ARG TORCH_VISION_VERSION
ARG TORCH_CUDA
ARG TORCH_NIGHTLY_INDEX_URL
ARG COMFYUI_PORT

USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

RUN python -m pip install --upgrade pip wheel setuptools && \
    if [[ "${TORCH_CHANNEL}" == "nightly" ]]; then \
      echo "[Torch] Using nightly channel (${TORCH_CUDA})"; \
      python -m pip install --no-cache-dir --pre \
        torch torchvision torchaudio \
        --index-url "${TORCH_NIGHTLY_INDEX_URL}/${TORCH_CUDA}"; \
    else \
      echo "[Torch] Using stable channel ${TORCH_VERSION} (${TORCH_CUDA})"; \
      python -m pip install --no-cache-dir \
        "torch==${TORCH_VERSION}" \
        "torchvision==${TORCH_VISION_VERSION}" \
        "torchaudio==${TORCH_VERSION}" \
        --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"; \
    fi

# 安装 jupyter 以兼容 start.sh
RUN python -m pip install --no-cache-dir \
      "jupyterlab>=4.0.0" \
      "notebook" \
      "ipykernel"

RUN python - <<'PY'
import torch, platform
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("Arch:", platform.machine())
print("CUDA arch list:", getattr(torch.cuda, "get_arch_list", lambda: "n/a")())
PY

# ==============================
# comfy-builder (Wan2.1-T2V-1.3B)
# ==============================
FROM python-env AS comfy-builder

ARG UBUNTU_USER
ARG INSTALL_NUNCHAKU
ARG NUNCHAKU_REPO
ARG NUNCHAKU_REF

WORKDIR /home/${UBUNTU_USER}

# ComfyUI 本体
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install --no-cache-dir -r requirements.txt

# Manager 节点
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git ComfyUI-Manager && \
    cd ComfyUI-Manager && \
    sed -i "s/^import manager_server  # noqa: F401$/try:\\n    import manager_server  # noqa: F401\\nexcept Exception as e:\\n    print('[ComfyUI-Manager] import failed:', e)/" __init__.py

# =========================================
# 安装 huggingface-cli + 通用下载脚本
# =========================================
USER root
RUN python -m pip install --no-cache-dir \
      "GitPython>=3.1.44" \
      "PyGithub" \
      "toml" \
      "huggingface_hub[cli]"

RUN cat >/usr/local/bin/hf_download.sh <<'HF'
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: hf_download.sh <REPO_ID> <TARGET_DIR> [TOKEN]" >&2
  exit 1
fi

REPO_ID="$1"
TARGET_DIR="$2"
TOKEN="${3:-}"

mkdir -p "${TARGET_DIR}"

echo "[hf_download] Downloading \${REPO_ID} -> \${TARGET_DIR}"

python - "$REPO_ID" "$TARGET_DIR" "$TOKEN" <<'PY'
import sys
from huggingface_hub import snapshot_download

if len(sys.argv) < 4:
    print("[hf_download][py] ERROR: need REPO_ID, TARGET_DIR, TOKEN", file=sys.stderr)
    sys.exit(1)

repo_id, target_dir, token = sys.argv[1:4]

kwargs = dict(
    local_dir=target_dir,
)

if token:
    kwargs["token"] = token

print(f"[hf_download][py] snapshot_download(repo_id={repo_id}, local_dir={target_dir})")
snapshot_download(repo_id=repo_id, **kwargs)
print("[hf_download][py] Done.")
PY

echo "[hf_download] Done."
HF

RUN chmod +x /usr/local/bin/hf_download.sh

# 回到 ubuntu 用户继续后续步骤
USER ${UBUNTU_USER}
RUN python -m pip install --no-cache-dir --user \
      "GitPython>=3.1.44" \
      "PyGithub" \
      "toml"

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

# 模型 & 目录结构（真正的模型运行时下载）
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output \
      /home/${UBUNTU_USER}/ComfyUI/models

# ==============================
# runtime
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

USER root
WORKDIR /home/${UBUNTU_USER}

# 这些 context 依赖 buildx bake 里的 contexts 配置
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY README.md      /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt /etc/yotta.txt
COPY --from=scripts start.sh /start.sh

# ==============================
# post_start.sh：运行时自动下载 + 启动 ComfyUI
# ==============================
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/comfyui.log
mkdir -p /home/ubuntu

# ========= 模型参数（运行时环境控制） =========
# 用户可以在 Pod / 容器里设置：
#   export WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"
#   export WAN_MODEL_DIR="/home/ubuntu/ComfyUI/models/wan2.1-t2v-1.3b"
#   export WAN_AUTO_DOWNLOAD="true"
#   export HF_TOKEN="hf_xxx"
MODEL_ID="${WAN_MODEL_ID:-Wan-AI/Wan2.1-T2V-1.3B}"
MODEL_DIR="${WAN_MODEL_DIR:-/home/ubuntu/ComfyUI/models/wan2.1-t2v-1.3b}"
AUTO_DOWNLOAD="${WAN_AUTO_DOWNLOAD:-true}"

echo "[WAN] MODEL_ID=${MODEL_ID}"
echo "[WAN] MODEL_DIR=${MODEL_DIR}"
echo "[WAN] WAN_AUTO_DOWNLOAD=${AUTO_DOWNLOAD}"

# ========= 自动下载逻辑 =========
if [[ "${AUTO_DOWNLOAD}" == "true" ]]; then
  if [ ! -d "${MODEL_DIR}" ] || [ -z "$(ls -A "${MODEL_DIR}" 2>/dev/null || true)" ]; then
    echo "[WAN] Model dir is empty, start downloading..."

    if [ -z "${HF_TOKEN:-}" ]; then
      echo "[WAN] ERROR: HF_TOKEN is empty, cannot download gated model: ${MODEL_ID}" >&2
      exit 2
    fi

    hf_download.sh "${MODEL_ID}" "${MODEL_DIR}" "${HF_TOKEN}"
    echo "[WAN] Download finished."
  else
    echo "[WAN] Model dir not empty, skip download."
  fi
else
  echo "[WAN] WAN_AUTO_DOWNLOAD != true, skip auto download. Expect model is already present."
fi

# ========= 启动 ComfyUI =========
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

VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output", "/home/${UBUNTU_USER}/ComfyUI/models"]

EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${COMFYUI_PORT:-8188}/" >/dev/null || exit 1

ENTRYPOINT ["/start.sh"]
