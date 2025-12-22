# ==============================
# Wan2.2-Animate-14B ComfyUI 基座构建参数
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
ARG PYTHON_VERSION="3.11"
ARG UBUNTU_USER="ubuntu"
ARG COMFYUI_PORT="8188"

# 是否安装 Nunchaku（默认：否，由 bake 覆盖）
ARG INSTALL_NUNCHAKU="false"
ARG NUNCHAKU_REPO=""
ARG NUNCHAKU_REF=""

# Torch / CUDA 相关参数（直接走 stable）
ARG TORCH_VERSION="2.4.1"
ARG TORCH_VISION_VERSION="0.19.1"
ARG TORCH_CUDA="cu121"  # cu121 在官方有 2.4.1 轮子

# Wan2.2-Animate 模型（构建阶段下载）
ARG WAN_MODEL_ID="Wan-AI/Wan2.2-Animate-14B"
# 关键：直接用 ComfyUI 的 models 根目录
ARG WAN_ROOT="/home/ubuntu/ComfyUI/models"

# 构建时使用的 HF_TOKEN（通过 buildx 注入，不在镜像里写死）
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
# python-env: 安装 PyTorch（stable + cu121）
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
    echo "[Torch] Using stable channel ${TORCH_VERSION} (${TORCH_CUDA})" && \
    python -m pip install --no-cache-dir \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCH_VISION_VERSION}" \
      "torchaudio==${TORCH_VERSION}" \
      --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"

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
# comfy-builder (Wan2.2-Animate-14B)
# ==============================
FROM python-env AS comfy-builder

ARG UBUNTU_USER
ARG INSTALL_NUNCHAKU
ARG NUNCHAKU_REPO
ARG NUNCHAKU_REF
ARG WAN_MODEL_ID
ARG WAN_ROOT
ARG HF_TOKEN

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

# 安装 GitPython + PyGithub + toml + huggingface_hub[cli]，并写入通用 hf_download.sh（root）
USER root
RUN python -m pip install --no-cache-dir \
      "GitPython>=3.1.44" \
      "PyGithub" \
      "toml" \
      "huggingface_hub[cli]"

# 通用 huggingface 下载脚本
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

kwargs = dict(local_dir=target_dir)
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

# 模型 & 目录结构
RUN mkdir -p \
      /home/${UBUNTU_USER}/models/ckpt \
      /home/${UBUNTU_USER}/models/vae \
      /home/${UBUNTU_USER}/models/lora \
      /home/${UBUNTU_USER}/models/clip \
      /home/${UBUNTU_USER}/ComfyUI/input \
      /home/${UBUNTU_USER}/output \
      /home/${UBUNTU_USER}/ComfyUI/models \
      "${WAN_ROOT}"

# ========= 构建阶段下载 Wan2.2-Animate-14B + I2V / VAE / Text Encoder / LoRA =========
RUN set -euo pipefail && \
    echo "[WAN2.2][build] MODEL_ID=${WAN_MODEL_ID}" && \
    echo "[WAN2.2][build] WAN_ROOT=${WAN_ROOT}" && \
    mkdir -p "${WAN_ROOT}" && \
    if [ -z "${HF_TOKEN:-}" ]; then \
      echo "[WAN2.2][build] WARNING: HF_TOKEN is empty, will try anonymous download (may fail if gated)" >&2; \
    fi && \
    \
    # 1) 主仓：Wan-AI/Wan2.2-Animate-14B（有就下，失败也不阻塞）
    echo "[WAN2.2][build] Downloading base repo: ${WAN_MODEL_ID}" && \
    hf_download.sh "${WAN_MODEL_ID}" "${WAN_ROOT}/wan2.2_animate_raw" "${HF_TOKEN}" || \
      echo "[WAN2.2][build] WARN: base repo download failed or partial, continuing with Comfy-Org repack..." >&2 && \
    \
    # 2) 从 Comfy-Org/Wan_2.2_ComfyUI_Repackaged 精确拉取所需文件并放到标准目录
    echo "[WAN2.2][build] Downloading I2V / VAE / text encoder / loras from Comfy-Org/Wan_2.2_ComfyUI_Repackaged" && \
    HF_TOKEN_ENV="${HF_TOKEN:-}" python - <<'PY'
import os
from pathlib import Path
import shutil
from huggingface_hub import snapshot_download

token = os.environ.get("HF_TOKEN_ENV") or None

models_root = Path("/home/ubuntu/ComfyUI/models").resolve()
repo_id = "Comfy-Org/Wan_2.2_ComfyUI_Repackaged"

patterns = [
    # diffusion (i2v)
    "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
    "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",
    # 你要是想顺带把 t2v / ti2v 也拉进来，可以加更多 pattern
    # "split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors",
    # "split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors",
    # "split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors",

    # text encoder
    "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",

    # VAEs
    "split_files/vae/wan2.2_vae.safetensors",
    "split_files/vae/wan_2.1_vae.safetensors",

    # LoRAs
    "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
    "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors",
]

print("[WAN2.2-extra][py] snapshot_download:", repo_id)
local_root = Path(
    snapshot_download(
        repo_id=repo_id,
        allow_patterns=patterns,
        token=token,
    )
).resolve()

mapping = {
    # diffusion
    "split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors":
        models_root / "diffusion_models" / "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors",
    "split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors":
        models_root / "diffusion_models" / "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors",

    # text encoder
    "split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors":
        models_root / "text_encoders" / "umt5_xxl_fp8_e4m3fn_scaled.safetensors",

    # VAE
    "split_files/vae/wan2.2_vae.safetensors":
        models_root / "vae" / "wan2.2_vae.safetensors",
    "split_files/vae/wan_2.1_vae.safetensors":
        models_root / "vae" / "wan_2.1_vae.safetensors",

    # LoRA
    "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors":
        models_root / "loras" / "wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors",
    "split_files/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors":
        models_root / "loras" / "wan2.2_i2v_lightx2v_4steps_lora_v1_low_noise.safetensors",
}

for rel, dst in mapping.items():
    src = (local_root / rel).resolve()
    if not src.is_file():
        raise SystemExit(f"[WAN2.2-extra][py] ERROR: missing expected file in snapshot: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"[WAN2.2-extra][py] installed {rel} -> {dst}")

print("[WAN2.2-extra][py] all extra files installed into ComfyUI/models")
PY

# ==============================
# runtime
# ==============================
FROM comfy-builder AS runtime

ARG UBUNTU_USER
ARG COMFYUI_PORT

# 运行时只需要端口，不需要模型相关 ENV
ENV COMFYUI_PORT=${COMFYUI_PORT}

USER root
WORKDIR /home/${UBUNTU_USER}

# 这些来自 docker buildx bake 的额外上下文（scripts/proxy/logo）
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY README.md      /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt /etc/yotta.txt
COPY --from=scripts start.sh /start.sh

# post_start.sh：容器内只负责启动 ComfyUI（不再下载模型）
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/home/ubuntu/comfyui.log
mkdir -p /home/ubuntu

echo "[WAN2.2] Using pre-baked models inside image."

sudo -u ubuntu bash -lc "
  cd /home/ubuntu/ComfyUI && \
  python -u main.py \
    --listen 0.0.0.0 \
    --port   \"${COMFYUI_PORT:-8188}\" \
  >> \"${LOG}\" 2>&1 &
"

echo "ComfyUI started on 0.0.0.0:${COMFYUI_PORT:-8188}, logs: ${LOG}"
EOS

RUN chmod +x /post_start.sh /start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# 注意：不再把 /home/ubuntu/ComfyUI/models 声明成 VOLUME，避免覆盖镜像内模型
VOLUME ["/home/${UBUNTU_USER}/models", "/home/${UBUNTU_USER}/output"]

# 暴露端口：Nginx / ComfyUI / SSH
EXPOSE 80
EXPOSE ${COMFYUI_PORT}
EXPOSE 22

# 健康检查：直接探 ComfyUI HTTP 端口
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${COMFYUI_PORT:-8188}/" >/dev/null || exit 1

ENTRYPOINT ["/start.sh"]
