# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.11"
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
    TORCH_CUDA_ARCH_LIST="89;90"

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
# 先装 software-properties-common，后续要用 add-apt-repository
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates curl wget git git-lfs \
      locales tzdata bash acl openssh-server nginx sudo tini ffmpeg \
      build-essential ninja-build pkg-config cmake; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale; \
    rm -rf /var/lib/apt/lists/*

# ===== Python 3.11（强制 python3 -> 3.11）=====
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python; \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py; \
    /usr/bin/python3 /tmp/get-pip.py; \
    rm -f /tmp/get-pip.py; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel

# ===== PyTorch（CUDA 12.1 轮子；和 12.8 运行时 ABI 通常兼容）=====
RUN python3 -m pip install --no-cache-dir \
      torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
      --index-url https://download.pytorch.org/whl/cu121

# ===== SGLang 依赖（先装构建工具）=====
RUN python3 -m pip install --no-cache-dir -U \
      packaging pybind11 cmake ninja

# ===== 从源码安装 SGLang（会编译 sgl_kernel）=====
# 说明：使用 --no-build-isolation 以当前环境的 torch/cuda 头文件进行编译
RUN python3 -m pip install --no-cache-dir --no-build-isolation \
      "sglang@git+https://github.com/sgl-project/sglang.git#subdirectory=python"

# ===== 运行期依赖（API/下载/编解码）=====
RUN python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" \
      huggingface_hub sentencepiece \
      fastapi uvicorn uvloop orjson \
      psutil pybase64 pyzmq \
      openai partial_json_parser \
      hf_transfer

# ===== 用户与权限 =====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace "$HF_HOME"

# ===== SSH 准备 =====
RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*

# ===== Nginx & 静态页（来自 bake contexts）=====
COPY --from=proxy   nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy   readme.html /usr/share/nginx/html/readme.html
COPY                README.md   /usr/share/nginx/html/README.md
COPY --from=logo    yotta.txt   /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ===== 启动脚本（来自 container-template）=====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# ===== post_start：后台启动 SGLang =====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/sglang.log
mkdir -p /workspace

# 如启用 HF_HUB_ENABLE_HF_TRANSFER=1，则提示缺包
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

# ===== 暴露端口 & Entrypoint =====
EXPOSE 30000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh && /post_start.sh && sleep infinity"]
