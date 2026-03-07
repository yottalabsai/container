# ==============================
# Wan2.1-T2V-1.3B ComfyUI Base Build Arguments
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# Whether to install Nunchaku (default: no, overridable via bake)
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

# Torch / CUDA parameters
ARG TORCH_CHANNEL="nightly"
ARG TORCH_VERSION="2.4.1"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu128"
ARG TORCH_NIGHTLY_INDEX_URL="https://download.pytorch.org/whl/nightly"

# Wan model (downloaded at build time)
ARG WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"

# HF token: must be passed in via bake
ARG HF_TOKEN=""

# ==============================
# Base: CUDA + system dependencies + Python + SSH
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

# Create regular user
RUN useradd -m -s /bin/bash "${UBUNTU_USER}" || true && \
    echo "${UBUNTU_USER}:ubuntu" | chpasswd && \
    mkdir -p /home/${UBUNTU_USER}/.ssh && \
    chown ${UBUNTU_USER}:${UBUNTU_USER} /home/${UBUNTU_USER}/.ssh && \
    chmod 700 /home/${UBUNTU_USER}/.ssh && \
    mkdir -p "${HF_HOME}" && chown -R ${UBUNTU_USER}:${UBUNTU_USER} "${HF_HOME}"

# SSH configuration
RUN sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config

# Install Python
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
# python-env: install PyTorch
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

# Install jupyter for start.sh compatibility
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

# Build-time Wan model parameters
ARG WAN_MODEL_ID="Wan-AI/Wan2.1-T2V-1.3B"
ARG HF_TOKEN

# Unified model root directory (defaults to /data, large storage)
ARG MODELS_ROOT="/data/comfyui/models"

ENV MODELS_ROOT=${MODELS_ROOT} \
    WAN_MODEL_ID=${WAN_MODEL_ID} \
    WAN_ROOT="${MODELS_ROOT}"

WORKDIR /home/${UBUNTU_USER}

# ComfyUI core
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    python -m pip install --no-cache-dir -r requirements.txt

# Manager node
RUN mkdir -p /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    cd /home/${UBUNTU_USER}/ComfyUI/custom_nodes && \
    git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git ComfyUI-Manager && \
    cd ComfyUI-Manager && \
    sed -i "s/^import manager_server  # noqa: F401$/try:\\n    import manager_server  # noqa: F401\\nexcept Exception as e:\\n    print('[ComfyUI-Manager] import failed:', e)/" __init__.py

# =========================================
# Install huggingface-cli + generic download script
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

echo "[hf_download] Downloading ${REPO_ID} -> ${TARGET_DIR}"

python - "$REPO_ID" "$TARGET_DIR" "$TOKEN" <<'PY'
import sys
import os
from pathlib import Path
from huggingface_hub import snapshot_download

if len(sys.argv) < 4:
    print("[hf_download][py] ERROR: need REPO_ID, TARGET_DIR, TOKEN", file=sys.stderr)
    sys.exit(1)

repo_id, target_dir, token = sys.argv[1:4]

os.environ.setdefault("HF_HUB_ENABLE_PROGRESS_BARS", "1")

kwargs = dict(
    local_dir=target_dir,
)

if token:
    kwargs["token"] = token

print(f"[hf_download][py] Start download: repo_id={repo_id}")
print(f"[hf_download][py] Target dir: {target_dir}")

before_files = set()
if os.path.isdir(target_dir):
    before_files = set(Path(target_dir).rglob("*"))

local_path = snapshot_download(repo_id=repo_id, **kwargs)

after_files = set(Path(target_dir).rglob("*"))
new_files = [p for p in after_files - before_files if p.is_file()]

total_size = sum(p.stat().st_size for p in new_files)

print(f"[hf_download][py] Downloaded {len(new_files)} new files, "
      f"total size = {total_size / (1024**3):.2f} GB")
print(f"[hf_download][py] Local snapshot path: {local_path}")
print("[hf_download][py] Done.")
PY

echo "[hf_download] Done."
HF

RUN chmod +x /usr/local/bin/hf_download.sh

# Pre-create /data/comfyui/models in image and grant access to ubuntu user
RUN mkdir -p "${MODELS_ROOT}" && \
    chown -R ${UBUNTU_USER}:${UBUNTU_USER} "$(dirname "${MODELS_ROOT}")"

# Switch back to ubuntu user for subsequent steps
USER ${UBUNTU_USER}
RUN python -m pip install --no-cache-dir --user \
      "GitPython>=3.1.44" \
      "PyGithub" \
      "toml"

# Optional: Nunchaku
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

# Base directories: no longer create ComfyUI/models directly, symlink to MODELS_ROOT instead
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output \
      "${MODELS_ROOT}" && \
    ln -sfn "${MODELS_ROOT}" "/home/${UBUNTU_USER}/ComfyUI/models"

# ========= Download Wan model at build time (HF_TOKEN required, full snapshot) =========
RUN set -euo pipefail && \
    if [ -z "${HF_TOKEN:-}" ]; then \
      echo "[WAN][build] ERROR: HF_TOKEN is empty."; \
      echo "[WAN][build] Please pass HF_TOKEN via bake variable, e.g.:"; \
      echo "[WAN][build]   HF_TOKEN=hf_xxx docker buildx bake wan21-all --no-cache --push"; \
      exit 2; \
    fi && \
    \
    MODEL_NAME="$(basename "${WAN_MODEL_ID}")" && \
    MODEL_DIR="${WAN_ROOT}/${MODEL_NAME}" && \
    echo "[WAN][build] MODEL_ID=${WAN_MODEL_ID}" && \
    echo "[WAN][build] WAN_ROOT=${WAN_ROOT}" && \
    echo "[WAN][build] MODEL_DIR=${MODEL_DIR}" && \
    mkdir -p "${MODEL_DIR}" && \
    \
    echo "[WAN][build] Start downloading model from HuggingFace (full snapshot)..." && \
    hf_download.sh "${WAN_MODEL_ID}" "${MODEL_DIR}" "${HF_TOKEN}" && \
    \
    if [ ! -d "${MODEL_DIR}" ]; then \
      echo "[WAN][build] ERROR: MODEL_DIR ${MODEL_DIR} does not exist after download" >&2; \
      exit 3; \
    fi && \
    if [ -z "$(ls -A "${MODEL_DIR}")" ]; then \
      echo "[WAN][build] ERROR: MODEL_DIR ${MODEL_DIR} is empty after download" >&2; \
      exit 4; \
    fi && \
    echo "[WAN][build] Download finished, snapshot at ${MODEL_DIR}" && \
    \
    # Create a shorter, more memorable symlink for easy selection in ComfyUI
    ln -sfn "${MODEL_DIR}" "/home/${UBUNTU_USER}/ComfyUI/models/wan2.1" && \
    echo "[WAN][build] Symlink created: /home/${UBUNTU_USER}/ComfyUI/models/wan2.1 -> ${MODEL_DIR}"

# ========= Download supplementary Wan2.1 Fun Camera 1.3B models =========
RUN set -euo pipefail && \
    REPACK_DIR="${MODELS_ROOT}/wan21_repack" && \
    echo "[WAN2.1-FUN][build] download Comfy-Org/Wan_2.1_ComfyUI_repackaged -> ${REPACK_DIR}" && \
    if [ -z "${HF_TOKEN:-}" ]; then \
      echo "[WAN2.1-FUN][build] WARNING: HF_TOKEN is empty, will try anonymous download (may fail if repo is gated)" >&2; \
    fi && \
    \
    # 1) Download the full Comfy-Org repack repo to /data/comfyui/models/wan21_repack
    hf_download.sh "Comfy-Org/Wan_2.1_ComfyUI_repackaged" "${REPACK_DIR}" "${HF_TOKEN}" && \
    \
    # 2) Ensure standard directories exist (all under MODELS_ROOT)
    mkdir -p \
      "${MODELS_ROOT}/diffusion_models" \
      "${MODELS_ROOT}/vae" \
      "${MODELS_ROOT}/text_encoders" \
      "${MODELS_ROOT}/clip_vision" \
      "${MODELS_ROOT}/loras" && \
    \
    echo "[WAN2.1-FUN][build] linking required safetensors ..." && \
    \
    # 2.1 text encoder: umt5_xxl_fp8_e4m3fn_scaled.safetensors
    if [ -f "${REPACK_DIR}/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" ]; then \
      ln -sf "${REPACK_DIR}/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
             "${MODELS_ROOT}/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"; \
    fi && \
    \
    # 2.2 VAE: wan_2.1_vae.safetensors
    if [ -f "${REPACK_DIR}/split_files/vae/wan_2.1_vae.safetensors" ]; then \
      ln -sf "${REPACK_DIR}/split_files/vae/wan_2.1_vae.safetensors" \
             "${MODELS_ROOT}/vae/wan_2.1_vae.safetensors"; \
    fi && \
    \
    # 2.3 CLIP Vision: clip_vision_h.safetensors
    if [ -f "${REPACK_DIR}/split_files/clip_vision/clip_vision_h.safetensors" ]; then \
      ln -sf "${REPACK_DIR}/split_files/clip_vision/clip_vision_h.safetensors" \
             "${MODELS_ROOT}/clip_vision/clip_vision_h.safetensors"; \
    fi && \
    \
    # 2.4 Diffusion: wan2.1_fun_camera_v1.1.3B_bf16.safetensors
    CAMERA_TARGET="${MODELS_ROOT}/diffusion_models/wan2.1_fun_camera_v1.1.3B_bf16.safetensors" && \
    if [ ! -f "${CAMERA_TARGET}" ]; then \
      CAMERA_SRC="$(find "${REPACK_DIR}" -maxdepth 4 -type f -name 'wan2.1_fun_camera*1.3B*bf16.safetensors' | head -n1 || true)" && \
      if [ -n "${CAMERA_SRC}" ]; then \
        echo "[WAN2.1-FUN][build] found camera model: ${CAMERA_SRC}"; \
        ln -sf "${CAMERA_SRC}" "${CAMERA_TARGET}"; \
      else \
        echo "[WAN2.1-FUN][build][WARN] camera 1.3B bf16 file not found under repack dir"; \
      fi; \
    fi && \
    \
    echo "[WAN2.1-FUN][build] links created under ${MODELS_ROOT}"

# ==============================
# runtime
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

ENV COMFYUI_PORT=${COMFYUI_PORT}

USER root
WORKDIR /home/${UBUNTU_USER}

# These contexts depend on the contexts configuration in buildx bake
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY README.md      /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt /etc/yotta.txt
COPY --from=scripts start.sh /start.sh

# ==============================
# post_start.sh: only checks and starts ComfyUI (no model download)
# ==============================
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/comfyui.log
mkdir -p /home/ubuntu

MODEL_ID="${WAN_MODEL_ID:-Wan-AI/Wan2.1-T2V-1.3B}"
WAN_ROOT="${WAN_ROOT:-/data/comfyui/models}"
MODEL_NAME="$(basename "${MODEL_ID}")"
MODEL_DIR="${WAN_ROOT}/${MODEL_NAME}"

echo "[WAN][runtime] MODEL_ID=${MODEL_ID}"
echo "[WAN][runtime] WAN_ROOT=${WAN_ROOT}"
echo "[WAN][runtime] MODEL_DIR=${MODEL_DIR}"

if [ -d "${MODEL_DIR}" ]; then
  echo "[WAN][runtime] Model dir exists."
else
  echo "[WAN][runtime][WARN] Model dir not found. Make sure model is baked into image or mounted via volume."
fi

# ========= Start ComfyUI =========
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
