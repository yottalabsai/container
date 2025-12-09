# ==============================
# Flux1-Dev ComfyUI 基座构建参数
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# 是否安装 Nunchaku（由 bake 决定）
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

# Torch / CUDA 相关参数
ARG TORCH_CHANNEL="nightly"          # nightly / stable
ARG TORCH_VERSION="2.4.1"           # stable 时使用
ARG TORCH_VISION_VERSION="0.19.1"   # stable 时使用
ARG TORCH_CUDA="cu128"              # 默认 cu128 适配 CUDA 12.8
ARG TORCH_NIGHTLY_INDEX_URL="https://download.pytorch.org/whl/nightly"

# 默认启用 VAE（运行时可用 ENABLE_FLUX_VAE 覆盖）
ARG ENABLE_FLUX_VAE="true"

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
    # 针对 5090 / Blackwell
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

# SSH 配置：允许密码登录，但禁止 root 登录
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
# python-env: 安装 PyTorch + Jupyter
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

# 简单的环境自检
RUN python - <<'PY'
import torch, platform
print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count() if torch.cuda.is_available() else 0)
print("Arch:", platform.machine())
print("CUDA arch list:", getattr(torch.cuda, "get_arch_list", lambda: "n/a")())
PY

# ==============================
# comfy-builder: 安装 ComfyUI + Manager + (可选) Nunchaku + 下载脚本
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

# ComfyUI Manager 节点
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git ComfyUI-Manager && \
    cd ComfyUI-Manager && \
    sed -i "s/^import manager_server  # noqa: F401$/try:\\n    import manager_server  # noqa: F401\\nexcept Exception as e:\\n    print('[ComfyUI-Manager] import failed:', e)/" __init__.py

# 安装 huggingface_hub 等工具
USER root
RUN python -m pip install --no-cache-dir \
      "GitPython>=3.1.44" \
      "PyGithub" \
      "toml" \
      "huggingface_hub[cli]"

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

# 基本目录结构
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output \
      /home/${UBUNTU_USER}/ComfyUI/models

# -------------------------------
# FLUX1-Dev 下载脚本（运行时调用）
# 环境变量：HF_TOKEN / FLUX_MODEL_DIR / ENABLE_FLUX_VAE
# -------------------------------
USER root
RUN cat >/usr/local/bin/flux_download.sh <<'FLUX'
#!/usr/bin/env bash
set -euo pipefail

# ==============================
# Minimal FLUX1-Dev downloader
# 环境变量：
#   HF_TOKEN         - 必填，HuggingFace token
#   FLUX_MODEL_DIR   - 可选，模型根目录，默认 /home/ubuntu/ComfyUI/models
#   ENABLE_FLUX_VAE  - 可选，默认 true
# ==============================

HF_TOKEN="${HF_TOKEN:-}"
FLUX_MODEL_DIR="${FLUX_MODEL_DIR:-/home/ubuntu/ComfyUI/models}"
ENABLE_FLUX_VAE="${ENABLE_FLUX_VAE:-true}"

if [[ -z "${HF_TOKEN}" ]]; then
  echo "[flux_download] HF_TOKEN is empty, cannot download FLUX models." >&2
  exit 1
fi

echo "[flux_download] ROOT=${FLUX_MODEL_DIR}, ENABLE_FLUX_VAE=${ENABLE_FLUX_VAE}"

python - "$FLUX_MODEL_DIR" "$ENABLE_FLUX_VAE" "$HF_TOKEN" <<'PY'
import sys
import shutil
from pathlib import Path
from huggingface_hub import snapshot_download

if len(sys.argv) < 4:
    print("[flux_download][py] Need FLUX_MODEL_DIR, ENABLE_FLUX_VAE, HF_TOKEN", file=sys.stderr)
    sys.exit(1)

root_dir = Path(sys.argv[1])
enable_flux_vae = sys.argv[2].lower() == "true"
token = sys.argv[3] or None

root_dir.mkdir(parents=True, exist_ok=True)

# Repos & filenames
UNET_REPO = "black-forest-labs/FLUX.1-dev"
UNET_FILE = "flux1-dev.safetensors"

VAE_REPO = "black-forest-labs/FLUX.1-dev"
VAE_FILE = "ae.safetensors"

ENCODER_REPO = "comfyanonymous/flux_text_encoders"
ENCODER_T5 = "t5xxl_fp8_e4m3fn_scaled.safetensors"
ENCODER_CLIP = "clip_l.safetensors"

unet_path = root_dir / "unet" / UNET_FILE
vae_path = root_dir / "vae" / VAE_FILE
t5_path = root_dir / "text_encoders" / ENCODER_T5
clip_path = root_dir / "text_encoders" / ENCODER_CLIP

# Create dirs
for p in [unet_path.parent, vae_path.parent, t5_path.parent, clip_path.parent]:
    p.mkdir(parents=True, exist_ok=True)

# Check what we need
need_unet = not unet_path.is_file()
need_vae = enable_flux_vae and (not vae_path.is_file())
need_t5 = not t5_path.is_file()
need_clip = not clip_path.is_file()

if not any([need_unet, need_vae, need_t5, need_clip]):
    print("[flux_download][py] All FLUX1-Dev files already exist, nothing to do.")
    sys.exit(0)

print(f"[flux_download][py] need_unet={need_unet}, need_vae={need_vae}, need_t5={need_t5}, need_clip={need_clip}")

def dl(repo_id: str, allow_patterns, tmp_dir: Path):
    tmp_dir.mkdir(parents=True, exist_ok=True)
    print(f"[flux_download][py] snapshot_download(repo_id={repo_id}, allow_patterns={allow_patterns})")
    snapshot_download(
        repo_id=repo_id,
        local_dir=tmp_dir.as_posix(),
        allow_patterns=allow_patterns,
        token=token,
    )

# UNET
if need_unet:
    tmp_unet = root_dir / "_tmp_unet"
    dl(UNET_REPO, [UNET_FILE], tmp_unet)
    src = tmp_unet / UNET_FILE
    if not src.is_file():
        print(f"[flux_download][py] ERROR: UNET file not found in tmp: {src}", file=sys.stderr)
        sys.exit(2)
    shutil.move(src.as_posix(), unet_path.as_posix())
    shutil.rmtree(tmp_unet, ignore_errors=True)

# VAE
if need_vae:
    tmp_vae = root_dir / "_tmp_vae"
    dl(VAE_REPO, [VAE_FILE], tmp_vae)
    src = tmp_vae / VAE_FILE
    if not src.is_file():
        print(f"[flux_download][py] ERROR: VAE file not found in tmp: {src}", file=sys.stderr)
        sys.exit(3)
    shutil.move(src.as_posix(), vae_path.as_posix())
    shutil.rmtree(tmp_vae, ignore_errors=True)

# TEXT ENCODERS
if need_t5 or need_clip:
    tmp_te = root_dir / "_tmp_text_encoders"
    patterns = []
    if need_t5:
        patterns.append(ENCODER_T5)
    if need_clip:
        patterns.append(ENCODER_CLIP)
    dl(ENCODER_REPO, patterns, tmp_te)

    if need_t5:
        src = tmp_te / ENCODER_T5
        if not src.is_file():
            print(f"[flux_download][py] ERROR: T5 encoder not found in tmp: {src}", file=sys.stderr)
            sys.exit(4)
        shutil.move(src.as_posix(), t5_path.as_posix())

    if need_clip:
        src = tmp_te / ENCODER_CLIP
        if not src.is_file():
            print(f"[flux_download][py] ERROR: CLIP encoder not found in tmp: {src}", file=sys.stderr)
            sys.exit(5)
        shutil.move(src.as_posix(), clip_path.as_posix())

    shutil.rmtree(tmp_te, ignore_errors=True)

print("[flux_download][py] FLUX1-Dev model installation complete.")
PY

# 权限收尾放在运行时脚本里做（这里用当前 FLUX_MODEL_DIR）
chown -R ubuntu:ubuntu "${FLUX_MODEL_DIR}"

echo "[flux_download] FLUX1-Dev model installation complete."
FLUX

RUN chmod +x /usr/local/bin/flux_download.sh
USER ${UBUNTU_USER}

# ==============================
# runtime
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT
ARG ENABLE_FLUX_VAE

# 默认环境变量（运行时可用 env 覆盖）
ENV COMFYUI_PORT=${COMFYUI_PORT} \
    ENABLE_FLUX_VAE=${ENABLE_FLUX_VAE} \
    FLUX_MODEL_DIR="/home/${UBUNTU_USER}/ComfyUI/models"

USER root
WORKDIR /home/${UBUNTU_USER}

# 这些来自 docker buildx bake 的额外上下文（scripts/proxy/logo）
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY README.md      /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt /etc/yotta.txt
COPY --from=scripts start.sh /start.sh

# post_start.sh：后台下载 FLUX + 启动 ComfyUI
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/comfyui.log
mkdir -p /home/ubuntu

# 后台下载 FLUX 模型（如果已存在则会跳过）
if command -v flux_download.sh >/dev/null 2>&1; then
  echo "[entry] spawn flux_download.sh in background ..."
  sudo -u ubuntu \
    HF_TOKEN="${HF_TOKEN:-}" \
    FLUX_MODEL_DIR="${FLUX_MODEL_DIR:-/home/ubuntu/ComfyUI/models}" \
    ENABLE_FLUX_VAE="${ENABLE_FLUX_VAE:-true}" \
    bash -lc "flux_download.sh >> /home/ubuntu/flux_download.log 2>&1 &"
else
  echo "[entry] flux_download.sh not found, skip model bootstrap."
fi

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

# 把 ComfyUI/models 也当成数据卷，方便挂载/持久化
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output", "/home/${UBUNTU_USER}/ComfyUI/models"]

# 暴露端口：Nginx / ComfyUI / SSH
EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

# 健康检查：直接探 ComfyUI HTTP 端口
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${COMFYUI_PORT:-8188}/" >/dev/null || exit 1

# 入口脚本来自 scripts 上下文的 start.sh
ENTRYPOINT ["/start.sh"]
