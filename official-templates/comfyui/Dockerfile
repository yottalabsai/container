# ===== Base & Args =====
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION
ARG TORCH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===== Env =====
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    COMFYUI_HOST=0.0.0.0 \
    COMFYUI_PORT=8188 \
    COMFYUI_EXTRA_ARGS=""

WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===== System deps =====
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs wget curl ca-certificates tzdata locales acl bash libgl1 \
      software-properties-common openssh-server nginx sudo tini ffmpeg && \
    git lfs install && \
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

# ===== PyTorch（可选）=====
RUN if [ -n "${TORCH}" ]; then pip install --no-cache-dir ${TORCH}; fi

# ===== 拉取 ComfyUI 源码 + 依赖 =====
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /opt/ComfyUI && \
    mkdir -p /workspace/ComfyUI/models && \
    rm -rf /opt/ComfyUI/models && ln -s /workspace/ComfyUI/models /opt/ComfyUI/models && \
    pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt

# ===== 用户与权限 =====
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu && \
    chown -R ubuntu:ubuntu /workspace /opt/ComfyUI

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
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ===== Start script =====
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# ===== post_start：后台启动 ComfyUI =====
RUN bash -lc 'cat > /post_start.sh <<\"EOS\"\n#!/usr/bin/env bash\nset -euo pipefail\n\nLOG=/workspace/comfyui.log\nmkdir -p /workspace\n\nsudo -u ubuntu bash -lc \"cd /opt/ComfyUI && \\\n  python3 -u main.py \\\n    --listen \\\"${COMFYUI_HOST:-0.0.0.0}\\\" \\\n    --port \\\"${COMFYUI_PORT:-8188}\\\" \\\n    ${COMFYUI_EXTRA_ARGS:-} \\\n  >> \\\"$LOG\\\" 2>&1 &\"\n\necho \"ComfyUI started on ${COMFYUI_HOST:-0.0.0.0}:${COMFYUI_PORT:-8188}. Logs: $LOG\"\nEOS\n' && chmod +x /post_start.sh

# ===== Ports & Entrypoint =====
EXPOSE 8188
USER ubuntu
WORKDIR /home/ubuntu
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/start.sh"]
