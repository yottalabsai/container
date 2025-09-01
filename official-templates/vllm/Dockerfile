# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION
ARG VLLM_PIP="vllm"
ARG VLLM_MODEL="Qwen/Qwen2.5-7B-Instruct"
ARG VLLM_EXTRA
ARG VLLM_PORT="8000"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    VLLM_HOST=0.0.0.0 \
    VLLM_PORT=${VLLM_PORT} \
    TRANSFORMERS_CACHE=/workspace/hf

WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
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

# ===== vLLM & HF 生态 =====
RUN pip install --no-cache-dir vllm && \
    pip install --no-cache-dir huggingface_hub sentencepiece \
                         "transformers>=4.40,<5"

# ===== User & Perm / SSH / Nginx / Banners（同上略）=====
RUN useradd -ms /bin/bash ubuntu && usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace
RUN mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && setfacl -R -m u:ubuntu:rwx /root/.ssh && \
    rm -f /etc/ssh/ssh_host_*
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# ===== post_start 起 vLLM =====
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
LOG=/workspace/vllm.log
mkdir -p /workspace
sudo -u ubuntu bash -lc "\
  python -m vllm.entrypoints.openai.api_server \
    --host \"${VLLM_HOST:-0.0.0.0}\" \
    --port \"${VLLM_PORT:-8000}\" \
    --model \"${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct}\" \
    ${VLLM_EXTRA:-} \
  >> \"$LOG\" 2>&1 &"
echo "vLLM started on \${VLLM_HOST:-0.0.0.0}:\${VLLM_PORT:-8000}. Logs: $LOG"
EOS
RUN chmod +x /post_start.sh

EXPOSE 8000
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]