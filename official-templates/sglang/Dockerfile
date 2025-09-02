# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# 可由 bake 覆盖的参数
ARG PYTHON_VERSION="3.11"
ARG SGLANG_REPO="https://github.com/sgl-project/sglang"
ARG SGLANG_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG SGLANG_EXTRA=""
ARG SGLANG_PORT="30000"

SHELL ["/bin/bash","-o","pipefail","-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    SGLANG_HOST=0.0.0.0 \
    SGLANG_PORT=${SGLANG_PORT} \
    # 4090=8.9, H200=9.0；多卡环境都覆盖
    TORCH_CUDA_ARCH_LIST="8.9;9.0"

# 工作目录与可写缓存
WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps（先装 software-properties-common，后面需要 add-apt-repository）=====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash \
      software-properties-common openssh-server nginx sudo tini ffmpeg \
      build-essential ninja-build pkg-config && \
    git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python & Pip（显式把 python3 指到 3.11，避免系统 3.10 干扰）=====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    /usr/bin/python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== PyTorch（CUDA 12.1 轮子；与 12.8 运行时 ABI 通常兼容）=====
# 如基础镜像已有 torch，可注释掉
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ===== SGLang（源码安装，生成 sgl_kernel）+ 运行期依赖 =====
RUN git clone --depth=1 --recursive ${SGLANG_REPO} /opt/sglang && \
    pip install --no-cache-dir -e /opt/sglang/python && \
    pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      sentencepiece huggingface_hub hf_transfer \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai partial_json_parser

# ===== User & Perm =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME" /opt/sglang

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

# 后台自启动 SGLang（OpenAI 兼容端点）
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/sglang.log
mkdir -p /workspace

# 如开启 HF_HUB_ENABLE_HF_TRANSFER=1，提示依赖
if [[ "${HF_HUB_ENABLE_HF_TRANSFER:-0}" == "1" ]]; then
  python3 - <<'PY' || true
try:
    import hf_transfer  # noqa: F401
except Exception as e:
    print("WARN: HF_HUB_ENABLE_HF_TRANSFER=1 but hf_transfer not installed:", e)
PY
fi

sudo -u ubuntu bash -lc "\
  nohup python3 -m sglang.launch_server \
    --host \"${SGLANG_HOST:-0.0.0.0}\" \
    --port \"${SGLANG_PORT:-30000}\" \
    --model \"${SGLANG_MODEL:-Qwen/Qwen2.5-7B-Instruct}\" \
    --download-dir \"${HF_HOME:-/workspace/hf}\" \
    ${SGLANG_EXTRA:-} >> \"$LOG\" 2>&1 &"

echo \"SGLang started on \${SGLANG_HOST:-0.0.0.0}:\${SGLANG_PORT:-30000}. Logs: $LOG\"
EOS
RUN chmod +x /post_start.sh

# ===== Ports & Entrypoint =====
EXPOSE 22 30000 8888
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh && /post_start.sh && sleep infinity"]
