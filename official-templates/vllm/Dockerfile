# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"
# 默认开源模型；如需换成 Llama 等 gated 模型，必须显式覆盖
ARG VLLM_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG VLLM_EXTRA=""
ARG VLLM_HOST="0.0.0.0"
ARG VLLM_PORT="8000"
# 1=尝试安装 FlashInfer（先装 wheel，失败则源码编译）
ARG INSTALL_FLASHINFER="0"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    VLLM_HOST=${VLLM_HOST} \
    VLLM_PORT=${VLLM_PORT} \
    HF_HOME=/workspace/hf

# 工作目录与可写缓存
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

# ===== Python & Pip（把 python / python3 都指到 3.11，避免混用）=====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    /usr/bin/python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    python -m pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== PyTorch（CUDA 12.1 轮子；与 12.8 运行时 ABI 通常兼容）=====
# 如基础镜像已装可注释
RUN python -m pip install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ===== vLLM & HF 生态 =====
RUN python -m pip install --no-cache-dir \
      vllm \
      "transformers>=4.40,<5" \
      sentencepiece \
      huggingface_hub \
      hf_transfer

# ===== 可选：FlashInfer（提升采样阶段性能）=====
# INSTALL_FLASHINFER=1 时尝试安装 wheel；失败则源码编译（支持 4090 / SM 8.9）
RUN if [[ "${INSTALL_FLASHINFER}" = "1" ]]; then \
      set -euo pipefail; \
      echo "[FlashInfer] trying wheel..."; \
      (python -m pip install --no-cache-dir flashinfer && echo "[FlashInfer] wheel OK") || \
      (echo "[FlashInfer] wheel failed, building from source..." && \
       git clone --recursive https://github.com/AnswerDotAI/FlashInfer.git /tmp/flashinfer && \
       export TORCH_CUDA_ARCH_LIST="8.9" && \
       python -m pip install -v /tmp/flashinfer/python && \
       rm -rf /tmp/flashinfer && \
       echo "[FlashInfer] built from source OK"); \
    fi

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

# 用 Python 3.11 启动 vLLM；所有参数有默认值，避免空字符串；下载目录指向 HF_HOME
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace

# 如开启 HF_HUB_ENABLE_HF_TRANSFER=1，确保 hf_transfer 存在（仅警告）
if [[ "${HF_HUB_ENABLE_HF_TRANSFER:-0}" == "1" ]]; then
  python - <<'PY' || true
try:
    import hf_transfer  # noqa: F401
except Exception as e:
    print("WARN: HF_HUB_ENABLE_HF_TRANSFER=1 but hf_transfer not installed:", e)
PY
fi

# 后台启动 vLLM（用 python(=3.11) 保证与安装解释器一致）
sudo -u ubuntu bash -lc "\
  nohup python -m vllm.entrypoints.openai.api_server \
    --host \"${VLLM_HOST:-0.0.0.0}\" \
    --port \"${VLLM_PORT:-8000}\" \
    --model \"${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}\" \
    --download-dir \"${HF_HOME:-/workspace/hf}\" \
    --trust-remote-code \
    ${VLLM_EXTRA:-} >> \"$LOG\" 2>&1 &"

echo \"vLLM started on \${VLLM_HOST:-0.0.0.0}:\${VLLM_PORT:-8000}. Logs: $LOG\"
EOS
RUN chmod +x /post_start.sh

# ===== Ports & Entrypoint =====
EXPOSE 8000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh && /post_start.sh && sleep infinity"]
