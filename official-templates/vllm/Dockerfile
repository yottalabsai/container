# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可以由 bake 覆盖的参数（非敏感）
ARG PYTHON_VERSION="3.11"
ARG VLLM_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG VLLM_EXTRA=""
ARG VLLM_PORT="8000"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=${VLLM_PORT} \
    HF_HOME=/workspace/hf

# 工作目录与可写缓存
WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash \
      software-properties-common openssh-server nginx sudo tini ffmpeg && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python & Pip（只建立 /usr/bin/python 软链，不动 /usr/bin/python3）=====
RUN if [ -n "${PYTHON_VERSION}" ]; then \
      add-apt-repository ppa:deadsnakes/ppa -y && \
      apt-get update -y && \
      apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      /usr/bin/python /tmp/get-pip.py && rm -f /tmp/get-pip.py; \
    fi; \
    pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== PyTorch（CUDA 12.1 轮子，通常与 12.8 运行时 ABI 兼容）=====
# 如已在基础镜像装好，可注释掉这一段
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ===== vLLM & HF 生态 =====
RUN pip install --no-cache-dir \
      vllm \
      huggingface_hub \
      sentencepiece \
      "transformers>=4.40,<5" \
      hf_transfer

# ===== User & Perm =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ===== SSH prep =====
RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*

# ===== Nginx & Static（来自 bake 的 contexts）=====
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ===== Start & post_start =====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# 用 python3 启动 vLLM，强兜底默认模型为 Qwen/Qwen2.5-7B-Instruct
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace

# 兼容：如开启 HF_HUB_ENABLE_HF_TRANSFER=1，则确保已安装 hf_transfer（仅警告，不阻塞）
if [[ "${HF_HUB_ENABLE_HF_TRANSFER:-0}" == "1" ]]; then
  python3 - <<'PY' || true
try:
    import hf_transfer  # noqa: F401
except Exception as e:
    print("WARN: HF_HUB_ENABLE_HF_TRANSFER=1 but hf_transfer not installed:", e)
PY
fi

# ===== 默认参数兜底（仅显式传入时覆盖）=====
VLLM_MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}"
VLLM_PORT="${VLLM_PORT:-8000}"
VLLM_HOST="${VLLM_HOST:-0.0.0.0}"
HF_HOME="${HF_HOME:-/workspace/hf}"

# ===== 启动 vLLM =====
sudo -u ubuntu bash -lc "\
  nohup python3 -m vllm.entrypoints.openai.api_server \
    --host \"$VLLM_HOST\" \
    --port \"$VLLM_PORT\" \
    --model \"$VLLM_MODEL\" \
    --download-dir \"$HF_HOME\" \
    --trust-remote-code \
    ${VLLM_EXTRA:-} >> \"$LOG\" 2>&1 &"

echo "vLLM started on ${VLLM_HOST}:${VLLM_PORT} with model ${VLLM_MODEL}. Logs: $LOG"
EOS
RUN chmod +x /post_start.sh

# ===== Ports & Entrypoint =====
EXPOSE 8000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh && /post_start.sh && sleep infinity"]
