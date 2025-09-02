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
    CUDACXX=/usr/local/cuda/bin/nvcc \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    HF_HOME=/workspace/hf \
    SGLANG_HOST=0.0.0.0 \
    SGLANG_PORT=${SGLANG_PORT} \
    # Torch 需要点号格式：8.9 / 9.0；默认给近代 GPU（Ada/Hopper）胖二进制
    TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0" \
    # 降并行防止编译峰值内存猛涨（也更稳定）
    CMAKE_BUILD_PARALLEL_LEVEL=1

WORKDIR /
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
# 关键：libnuma-dev / libibverbs-dev 是 sgl-kernel(mscclpp) 的必需；cmake 用 pip 装新版避免 policy 报错
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      software-properties-common ca-certificates curl wget git git-lfs \
      locales tzdata bash acl openssh-server nginx sudo tini ffmpeg \
      build-essential ninja-build pkg-config \
      libnuma-dev numactl libibverbs-dev rdma-core libhwloc-dev \
      libgl1; \
    git lfs install; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale; \
    rm -rf /var/lib/apt/lists/*

# ===== Python 3.11 =====
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

# ===== Pip toolchain（固定新 cmake & scikit-build-core）=====
RUN python3 -m pip install --no-cache-dir -U \
      "cmake>=3.30" ninja packaging pybind11 "scikit-build-core>=0.11"

# ===== PyTorch（CUDA 12.1 轮子；与 12.8 驱动/运行时兼容）=====
RUN python3 -m pip install --no-cache-dir \
      torch==2.5.1+cu121 torchvision==0.20.1+cu121 torchaudio==2.5.1+cu121 \
      --index-url https://download.pytorch.org/whl/cu121

# 让 CMake 能找到 Torch 的 CMake 包（供 sgl-kernel 编译用）
ENV Torch_DIR=/usr/local/lib/python${PYTHON_VERSION}/dist-packages/torch/share/cmake/Torch

# ===== 先从源码编译安装 sgl-kernel（更稳）=====
# 用 --no-build-isolation 复用当前 torch/cuda 头文件环境；Ninja + 我们的 ENV 即可
RUN python3 -m pip install --no-cache-dir --no-build-isolation \
      "git+https://github.com/sgl-project/sglang.git#subdirectory=sgl-kernel"

# ===== 再装 SGLang 本体 =====
RUN python3 -m pip install --no-cache-dir --no-build-isolation \
      "sglang@git+https://github.com/sgl-project/sglang.git#subdirectory=python"

# ===== 运行期依赖 =====
RUN python3 -m pip install --no-cache-dir \
      "transformers>=4.40,<5" huggingface_hub sentencepiece \
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
COPY --from=scripts /start.sh /start.sh
RUN chmod +x /start.sh

# ===== post_start：后台启动 SGLang =====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/sglang.log
mkdir -p /workspace

# 提示 hf_transfer 可选
if [[ "${HF_HUB_ENABLE_HF_TRANSFER:-0}" == "1" ]]; then
  python3 - <<'PY' || true
try:
    import hf_transfer  # noqa: F401
except Exception as e:
    print("WARN: HF_HUB_ENABLE_HF_TRANSFER=1 but hf_transfer not installed:", e)
PY
fi

# 允许外部通过 SGLANG_EXTRA 传参（如 --tp-size、--max-prefill-tokens 等）
sudo -u ubuntu bash -lc "\
  nohup python3 -m sglang.launch_server \
    --host \"${SGLANG_HOST:-0.0.0.0}\" \
    --port \"${SGLANG_PORT:-30000}\" \
    --model-path \"${SGLANG_MODEL:-Qwen/Qwen2.5-7B-Instruct}\" \
    --download-dir \"${HF_HOME:-/workspace/hf}\" \
    ${SGLANG_EXTRA:-} >> \"$LOG\" 2>&1 &"

echo \"SGLang started on \${SGLANG_HOST:-0.0.0.0}:\${SGLANG_PORT:-30000}. Logs: $LOG\"
EOS
RUN chmod +x /post_start.sh

# ===== 健康检查（SGLang OpenAI 兼容接口）=====
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=5 \
  CMD curl -sf "http://127.0.0.1:${SGLANG_PORT}/v1/models" >/dev/null || exit 1

# ===== 端口 & Entrypoint =====
EXPOSE 22 80 8888 30000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/bin/bash","-lc","/start.sh && /post_start.sh && sleep infinity"]
