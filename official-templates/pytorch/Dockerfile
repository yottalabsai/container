ARG BASE_IMAGE="nvidia/cuda:13.0.0-cudnn-devel-ubuntu22.04"
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
# Note: use full version number (python.org does not have tarballs for short versions like 3.11)
ARG PYTHON_VERSION="3.11.14"

# PyTorch 2.9: using nightly cu128
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"

ARG NCCL_TESTS_VERSION="v2.13.11"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/opt/conda/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=yotta \
    # 问题6: 抑制 pip root 用户警告
    PIP_ROOT_USER_ACTION=ignore \
    # 问题4: uv 默认安装到系统 Python，无需每次加 --system
    UV_SYSTEM_PYTHON=1

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace /root

# ===============================
# Base system packages
# ===============================
# 问题7b: 新增 cmake（编译 CUDA 扩展 / flash-attn 必需）
# 问题8:  新增 nano（新手友好编辑器）、screen（后台会话）、nvtop（GPU 实时监控）
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git acl wget curl ca-certificates bash \
      libgl1 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim nano screen zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config cmake \
      nvtop \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd /var/log/supervisor \
    && chmod 700 /var/run/sshd /var/log/supervisor \
    && chmod 755 /var/log \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# Remove ubuntu user (for security: prevent unauthorized SSH access)
# ===============================
RUN userdel -r ubuntu || true

# ===============================
# Python 3.11 (build from source, with ensurepip)
# ===============================
RUN set -eux; \
    PY_MM="$(echo "${PYTHON_VERSION}" | awk -F. '{print $1"."$2}')"; \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev \
    && curl -fSL --retry 10 --retry-delay 2 --retry-all-errors \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
      -o /tmp/Python.tgz \
    && mkdir -p /tmp/python-src \
    && tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1 \
    && rm -f /tmp/Python.tgz \
    && cd /tmp/python-src \
    && ./configure --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && cd / \
    && rm -rf /tmp/python-src \
    && ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python \
    && ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python3 \
    # 问题3: 创建 pip / pip3 软链接，确保 `pip install` 直接可用
    && ln -sf "/usr/local/bin/pip${PY_MM}" /usr/local/bin/pip \
    && ln -sf "/usr/local/bin/pip${PY_MM}" /usr/local/bin/pip3 \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# PyTorch (nightly cu128)
# ===============================
RUN python -m pip install --no-cache-dir ${TORCH}

# ===============================
# Jupyter + common CLI tools (huggingface-cli / datasets-cli)
# ===============================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

# ===============================
# 问题5: 科学计算与 ML 常用包（避免用户每写一行 import 就要停下来安装）
# ===============================
RUN python -m pip install --no-cache-dir \
      numpy \
      scipy \
      pandas \
      matplotlib \
      Pillow \
      scikit-learn \
      opencv-python-headless \
      tqdm \
      transformers \
      accelerate \
      tokenizers \
      safetensors \
      tensorboard \
      einops

# ===============================
# 问题4: 安装 uv（UV_SYSTEM_PYTHON=1 已在 ENV 中设置，直接 uv pip install 即可）
# ===============================
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -sf /root/.local/bin/uv /usr/local/bin/uv && \
    ln -sf /root/.local/bin/uvx /usr/local/bin/uvx

# ===============================
# Build-time assertion: verify Jupyter installation
# ===============================
RUN python -c "import jupyter; import notebook; import jupyterlab; print('jupyter ok')"

# ===============================
# Configure JupyterLab: auto-login with token (no password prompt)
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
# NCCL tests (build from source, force MPI=0 to avoid mpi.h missing)
# ===============================
RUN set -eux; \
    git clone --branch "${NCCL_TESTS_VERSION}" --depth 1 \
      https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests; \
    make -C /opt/nccl-tests -j"$(nproc)" MPI=0; \
    ln -sf /opt/nccl-tests/build/* /usr/local/bin/; \
    rm -rf /opt/nccl-tests/.git

# ===============================
# CUDA bin convenience
# ===============================
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/ || true

# ===============================
# Supervisor configuration
# ===============================
RUN mkdir -p /usr/local/bin && \
    chmod 755 /workspace /var/run /var/lib/nginx && \
    mkdir -p /run/sshd && \
    chmod 700 /run/sshd

COPY --from=scripts updated_start.sh /updated_start.sh
RUN chmod 755 /updated_start.sh && \
    sed -i 's/\r$//' /updated_start.sh

# ===============================
# nginx / branding
# ===============================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt

# 问题9: branding 写入 /etc/profile（对所有登录 shell 生效，包括 SSH 直接登录）
# 同时保留 .bashrc（兼容交互式非登录 shell）
RUN echo 'cat /etc/yotta.txt' >> /etc/profile && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc

# 问题7(SSH/Jupyter 身份一致): 强制 SSH 以 root 登录，与 Jupyter 保持一致
# 注意: updated_start.sh 中若有创建非 root 用户的逻辑，需同步移除
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

# ===============================
# Ports (avoid inline comments to prevent containerPort parsing failures on some platforms)
# ===============================
EXPOSE 22 80 8888

# ===============================
# Entrypoint: root runs updated_start.sh with explicit bash (ensures bash syntax works)
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-c", "exec /bin/bash /updated_start.sh"]
