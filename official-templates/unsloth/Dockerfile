# ===============================
# Build args
# ===============================
ARG PYTHON_VERSION="3.11.14"

# ===============================
# logo + scripts + proxy stages
# ===============================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY container-template/start1.sh start1.sh

FROM scratch AS proxy
COPY container-template/proxy/nginx.conf nginx.conf
COPY container-template/proxy/readme.html readme.html

# ===============================
# main stage
# ===============================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

# Re-declare ARGs after FROM
ARG PYTHON_VERSION="3.11.14"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=yotta

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace /root

# ===============================
# System packages
# ===============================
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git \
      build-essential pkg-config \
      software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof \
      pciutils iproute2; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    mkdir -p /var/run/sshd /var/log/supervisor; \
    chmod 700 /var/run/sshd /var/log/supervisor; \
    chmod 755 /var/log; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ===============================
# Remove ubuntu user (security: prevent unauthorized SSH access)
# ===============================
RUN userdel -r ubuntu || true

# ===============================
# Python (build from source, with ensurepip)
# ===============================
RUN set -eux; \
    PY_MM="$(echo "${PYTHON_VERSION}" | awk -F. '{print $1"."$2}')"; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev; \
    curl -fSL --retry 10 --retry-delay 2 --retry-all-errors \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
      -o /tmp/Python.tgz; \
    mkdir -p /tmp/python-src; \
    tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1; \
    rm -f /tmp/Python.tgz; \
    cd /tmp/python-src; \
    ./configure --with-ensurepip=install; \
    make -j"$(nproc)"; \
    make altinstall; \
    cd /; \
    rm -rf /tmp/python-src; \
    ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python; \
    ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python3; \
    python -m pip install --no-cache-dir --upgrade pip setuptools wheel; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ===============================
# PyTorch (cu128)
# ===============================
RUN python -m pip install --no-cache-dir \
      --index-url https://download.pytorch.org/whl/cu128 \
      torch torchvision torchaudio

# ===============================
# Unsloth + dependencies
# ===============================
RUN python -m pip install --no-cache-dir \
      unsloth vllm \
      huggingface_hub datasets; \
    python -m pip install --no-cache-dir xformers --no-deps; \
    python -m pip install --no-cache-dir triton

# ===============================
# Jupyter + common tools
# ===============================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 ipykernel

# ===============================
# Build-time assertion: verify key packages
# (unsloth requires GPU at import time, so only check it's installed)
# ===============================
RUN python -c "import torch; import jupyterlab; from importlib.metadata import version; print(f'unsloth=={version(\"unsloth\")}  torch=={torch.__version__}  ok')"

# ===============================
# Configure JupyterLab
# ===============================
RUN mkdir -p /root/.jupyter && printf '%s\n' \
    'c.ServerApp.token = "yotta"' \
    'c.ServerApp.password = ""' \
    'c.ServerApp.allow_remote_access = True' \
    'c.ServerApp.allow_origin = "*"' \
    'c.NotebookApp.token = "yotta"' \
    'c.NotebookApp.password = ""' \
    'c.NotebookApp.allow_remote_access = True' \
    > /root/.jupyter/jupyter_lab_config.py && \
    chmod 600 /root/.jupyter/jupyter_lab_config.py

# ===============================
# Download Unsloth notebook templates
# ===============================
RUN set -eux; \
    cd /tmp; \
    git clone --depth=1 https://github.com/unslothai/notebooks.git unsloth-notebooks-src; \
    mkdir -p /workspace/unsloth-notebooks; \
    cp -a unsloth-notebooks-src/original_template/. /workspace/unsloth-notebooks/; \
    cp -a unsloth-notebooks-src/template.ipynb /workspace/unsloth-notebooks/ || true; \
    rm -rf /tmp/unsloth-notebooks-src

# ===============================
# CUDA bin convenience
# ===============================
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/ || true

# ===============================
# Supervisor dirs
# ===============================
RUN mkdir -p /var/log/supervisor /usr/local/bin && \
    chmod 777 /var/log/supervisor /workspace /var/run /var/lib/nginx && \
    mkdir -p /run/sshd && \
    chmod 700 /run/sshd

# ===============================
# start1.sh
# ===============================
COPY --from=scripts start1.sh /start1.sh
RUN chmod 755 /start1.sh && \
    sed -i 's/\r$//' /start1.sh

# ===============================
# nginx / branding
# ===============================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Ports
# ===============================
EXPOSE 22 80 8888

# ===============================
# Entrypoint: root runs start1.sh
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-c", "exec /bin/bash /start1.sh"]
