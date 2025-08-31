# ===== Base & Args =====
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION
ARG VLLM_PIP
ARG VLLM_MODEL
ARG VLLM_EXTRA

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=8000

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
        "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv"; \
    fi && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    pip install --upgrade --no-cache-dir pip setuptools wheel

# ===== vLLM =====
RUN if [ -n "${VLLM_PIP}" ]; then pip install --no-cache-dir ${VLLM_PIP}; fi

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
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===== Start & post_start =====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# 以 ubuntu 用户后台启动 vLLM OpenAI 兼容服务
RUN bash -lc 'cat > /post_start.sh <<\"EOS\"\n#!/usr/bin/env bash\nset -euo pipefail\n\nLOG=/workspace/vllm.log\nmkdir -p /workspace\n\nsudo -u ubuntu bash -lc \"\\\n  python -m vllm.entrypoints.openai.api_server \\\n    --host \\\"${VLLM_HOST:-0.0.0.0}\\\" \\\n    --port \\\"${VLLM_PORT:-8000}\\\" \\\n    --model \\\"${VLLM_MODEL:-meta-llama/Llama-3.1-8B-Instruct}\\\" \\\n    ${VLLM_EXTRA:-} \\\n  >> \\\"$LOG\\\" 2>&1 &\"\n\necho \"vLLM server started on ${VLLM_HOST:-0.0.0.0}:${VLLM_PORT:-8000}. Logs: $LOG\"\nEOS\n' && chmod +x /post_start.sh

# ===== Ports & Entry =====
EXPOSE 8000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
