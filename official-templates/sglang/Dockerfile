# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION
ARG SGLANG_PIP="sglang"
ARG SGLANG_MODEL="meta-llama/Llama-3.1-8B-Instruct"
ARG SGLANG_EXTRA
ARG SGLANG_PORT="30000"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    SGLANG_HOST=0.0.0.0 \
    SGLANG_PORT=${SGLANG_PORT}

WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===== System deps =====
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git wget curl ca-certificates tzdata locales acl bash \
      software-properties-common openssh-server nginx sudo tini && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python & Pip =====
RUN if [ -n "${PYTHON_VERSION}" ]; then \
      add-apt-repository ppa:deadsnakes/ppa -y && \
      apt-get update -y && \
      apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
      python /tmp/get-pip.py && rm -f /tmp/get-pip.py; \
    fi; \
    pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== Torch (CUDA 12.1 wheels) =====
RUN pip install --no-cache-dir torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

# ===== SGLang + 依赖（补齐一切缺口）=====
RUN if [ -n "${SGLANG_PIP}" ]; then pip install --no-cache-dir ${SGLANG_PIP}; fi \
    && pip install --no-cache-dir pybase64 \
    && pip install --no-cache-dir "pydantic<2" \
    && pip install --no-cache-dir orjson \
    && pip install --no-cache-dir uvicorn \
    && pip install --no-cache-dir uvloop \
    && pip install --no-cache-dir fastapi

# ===== User & Perm =====
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace

# ===== SSH prep =====
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*

# ===== Nginx & Static =====
# 需要在 bake 中声明 contexts: scripts / proxy / logo
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# Welcome Message
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m and \033[1;34mhttps://www.yottalabs.ai/\033[0m\n\n"' >> /root/.bashrc

# ===== Start & post_start =====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# 后台启动 SGLang
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

LOG=/workspace/sglang.log
mkdir -p /workspace

sudo -u ubuntu bash -lc "\
  python -m sglang.launch_server \
    --host \"${SGLANG_HOST:-0.0.0.0}\" \
    --port \"${SGLANG_PORT:-30000}\" \
    --model \"${SGLANG_MODEL:-meta-llama/Llama-3.1-8B-Instruct}\" \
    ${SGLANG_EXTRA:-} \
  >> \"$LOG\" 2>&1 &"

echo "SGLang server started on ${SGLANG_HOST:-0.0.0.0}:${SGLANG_PORT:-30000}. Logs: $LOG"
EOS
RUN chmod +x /post_start.sh

# ===== Ports & Entrypoint =====
EXPOSE 30000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]