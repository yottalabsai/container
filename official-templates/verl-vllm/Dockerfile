# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"

# 默认跑 Verl 大模型
ARG VLLM_MODEL="Verl/Wan2.2"
ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"

# 资源相关（TP、大 context、显存利用率）
ARG TP_SIZE="1"
ARG MAX_MODEL_LEN="32768"
ARG GPU_MEM_UTIL="0.92"

# FlashAttn 开关（true/false）
ARG INSTALL_FLASHATTN="false"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    VLLM_MODEL=${VLLM_MODEL} \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    TP_SIZE=${TP_SIZE} \
    MAX_MODEL_LEN=${MAX_MODEL_LEN} \
    GPU_MEM_UTIL=${GPU_MEM_UTIL}

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash \
      software-properties-common openssh-server nginx sudo tini ffmpeg \
      build-essential pkg-config ninja-build && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python 3.11（和你 start.sh 里的 python3.11 对齐）=====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    python -m pip install --no-cache-dir -U pip setuptools wheel

# ===== PyTorch: nightly cu126（支持 5090 / Blackwell）=====
RUN python -m pip install --no-cache-dir --pre \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/nightly/cu126

# ===== vLLM & HuggingFace & Jupyter =====
RUN python -m pip install --no-cache-dir \
      vllm \
      "transformers>=4.40,<5" \
      sentencepiece \
      huggingface_hub \
      hf_transfer \
      jupyterlab

# ===== FlashAttn（按需开启）=====
RUN if [[ "${INSTALL_FLASHATTN}" = "true" ]]; then \
      set -euo pipefail; \
      echo "[FlashAttn] trying wheel..."; \
      python -m pip install --no-cache-dir flash-attn || \
      echo "[FlashAttn] install failed, skipping"; \
    fi

# ===== ubuntu 用户，用于你 start.sh 里的 sudo chown ubuntu:ubuntu =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ===== SSH 目录（避免 start.sh 里 ssh-keygen 报目录不存在）=====
RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh

# ===== Nginx / README / logo（来自 proxy / logo context）=====
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ===== post_start.sh：你 start.sh 会执行它，我们在这里起 vLLM =====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/workspace/vllm.log
mkdir -p /workspace

echo "[vLLM] Launching model: ${VLLM_MODEL}"
echo "[vLLM] host=${VLLM_HOST:-0.0.0.0} port=${VLLM_PORT:-8000}"
echo "[vLLM] TP_SIZE=${TP_SIZE:-1} MAX_MODEL_LEN=${MAX_MODEL_LEN:-32768} GPU_MEM_UTIL=${GPU_MEM_UTIL:-0.9}"

nohup python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST:-0.0.0.0}" \
  --port "${VLLM_PORT:-8000}" \
  --model "${VLLM_MODEL}" \
  --download-dir "${HF_HOME:-/workspace/hf}" \
  --trust-remote-code \
  --tensor-parallel-size "${TP_SIZE:-1}" \
  --max-model-len "${MAX_MODEL_LEN:-32768}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL:-0.9}" \
  >> "$LOG" 2>&1 &

echo "[vLLM] started, logs: $LOG"
EOS

RUN chmod +x /post_start.sh

# ===== 拷贝你现有的 start.sh（来自 scripts context）=====
COPY --from=scripts start.sh /start.sh
RUN chmod +x /start.sh

# ===== Ports / Entry =====
# 22: ssh（start.sh 会开） 8000: vLLM OpenAI API  8888: Jupyter（如果你设置 JUPYTER_PASSWORD 才会启）
EXPOSE 22 8000 8888

WORKDIR /root
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh"]
