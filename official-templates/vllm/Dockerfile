# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
ARG VLLM_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG VLLM_PORT="8000"
ARG VLLM_EXTRA=""

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=${VLLM_PORT} \
    VLLM_MODEL=${VLLM_MODEL}

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash libgl1 \
      software-properties-common openssh-server nginx sudo tini ffmpeg \
      build-essential pkg-config && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python & Pip（仅建 /usr/bin/python 软链，不动 python3）=====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    /usr/bin/python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== PyTorch（CUDA 12.1 轮子）=====
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ===== vLLM & runtime deps =====
RUN pip install --no-cache-dir \
      "vllm>=0.10.0" \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai hf_transfer

# ===== User & SSH 基础 =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_* && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ===== Nginx & Static（来自 bake contexts）=====
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ===== 原有 start.sh（来自 scripts context）=====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# ===== 业务：post_start（后台拉起 vLLM）=====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace "${HF_HOME:-/workspace/hf}"

# 若启用 HF_TRANSFER 则提示包缺失
if [[ "${HF_HUB_ENABLE_HF_TRANSFER:-0}" == "1" ]]; then
  python3 - <<'PY' || true
try:
    import hf_transfer  # noqa: F401
except Exception as e:
    print("WARN: HF_HUB_ENABLE_HF_TRANSFER=1 but hf_transfer not installed:", e)
PY
fi

# 后台启动 vLLM
sudo -u ubuntu bash -lc "\
  nohup python3 -m vllm.entrypoints.openai.api_server \
    --host \"${VLLM_HOST:-0.0.0.0}\" \
    --port \"${VLLM_PORT:-8000}\" \
    --model \"${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}\" \
    --download-dir \"${HF_HOME:-/workspace/hf}\" \
    --trust-remote-code \
    ${VLLM_EXTRA:-} >> \"$LOG\" 2>&1 &"
echo \"vLLM started on \${VLLM_HOST:-0.0.0.0}:\${VLLM_PORT:-8000}. Logs: $LOG\"
EOS
RUN chmod +x /post_start.sh

# ===== 入口包装：先跑 /start.sh，再跑 /post_start.sh，再保活 =====
RUN bash -lc 'cat > /entrypoint.sh <<'"'"'EOS'"'"'\n\
#!/usr/bin/env bash\n\
set -euo pipefail\n\
log(){ echo "[$(date +%F_%T)] $*"; }\n\
if [[ -x /start.sh ]]; then log "running /start.sh"; /start.sh || { log "/start.sh failed"; exit 1; }; else log "WARN: /start.sh missing"; fi\n\
if [[ -f /post_start.sh ]]; then log "running /post_start.sh"; /post_start.sh || log "WARN: /post_start.sh failed"; else log "no /post_start.sh"; fi\n\
if [[ -n "${FOREGROUND_CMD:-}" ]]; then log "foreground: ${FOREGROUND_CMD}"; exec bash -lc "${FOREGROUND_CMD}"; else log "sleep infinity"; exec bash -lc "sleep infinity"; fi\n\
EOS' && chmod +x /entrypoint.sh

# ===== Port & Entrypoint =====
EXPOSE 8000
ENTRYPOINT ["/usr/bin/tini","-g","--","/entrypoint.sh"]
CMD []