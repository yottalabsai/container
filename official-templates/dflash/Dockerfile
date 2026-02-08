ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
# 注意：用完整版本号（否则 python.org 没有 3.11 这种 tarball）
ARG PYTHON_VERSION="3.11.14"

# PyTorch：nightly cu128（按你原来的方式）
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
    CUDA_HOME=/usr/local/cuda \
    JUPYTER_PASSWORD=ubuntu

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===============================
# Base system packages（按你给的案例原样 + 补 ninja）
# ===============================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git acl wget curl ca-certificates bash \
      libgl1 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config ninja-build \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# uv (Astral) - Python package manager
# - 固定安装到 /usr/local/bin
# - 避免修改 shell profile（适合容器/CI）
# ===============================
ARG UV_VERSION="latest"
RUN set -eux; \
    if [ "${UV_VERSION}" = "latest" ]; then \
      curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL="/usr/local/bin" sh; \
    else \
      curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | env UV_UNMANAGED_INSTALL="/usr/local/bin" sh; \
    fi; \
    uv --version

# ===============================
# Miniconda
# ===============================
ARG MINICONDA_VERSION="py311_24.1.2-0"
ARG CONDA_DIR="/opt/conda"

RUN set -eux; \
    ARCH="$(uname -m)"; \
    case "${ARCH}" in \
      x86_64)  MINICONDA_ARCH="x86_64" ;; \
      aarch64) MINICONDA_ARCH="aarch64" ;; \
      *) echo "Unsupported arch: ${ARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL \
      "https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-${MINICONDA_ARCH}.sh" \
      -o /tmp/miniconda.sh; \
    bash /tmp/miniconda.sh -b -p "${CONDA_DIR}"; \
    rm -f /tmp/miniconda.sh; \
    "${CONDA_DIR}/bin/conda" config --system --set auto_activate_base false; \
    "${CONDA_DIR}/bin/conda" clean -afy

RUN ln -sf /opt/conda/bin/conda /usr/local/bin/conda

# ===============================
# Python 3.11 (build from source, with ensurepip)
# - 保留 system python3.11：给 /start.sh / jupyter 之类用（你原有逻辑）
# - 但不再把 /usr/bin/python 指向 system python，避免 runtime 跑到“没装 torch”的 python
# ===============================
RUN set -eux; \
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
    && ./configure --enable-optimizations --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && cd / \
    && rm -rf /tmp/python-src \
    && /usr/local/bin/python3.11 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# 关键修复：让“python/pip 默认就是 conda python”
# - 避免 start.sh / 登录 shell PATH 不含 /opt/conda/bin 时跑到 system python
# - system python 仍然可用：/usr/local/bin/python3.11
# ===============================
RUN set -eux; \
    ln -sf /opt/conda/bin/python /usr/bin/python; \
    ln -sf /opt/conda/bin/python /usr/bin/python3; \
    ln -sf /opt/conda/bin/python /usr/local/bin/python; \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/00-conda-path.sh; \
    chmod 644 /etc/profile.d/00-conda-path.sh

# ===============================
# PyTorch (nightly cu128) —— 永远用 conda python 装
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir --pre --upgrade --force-reinstall ${TORCH}; \
    /opt/conda/bin/python -m pip install --no-cache-dir --upgrade --force-reinstall "fsspec[http]==2025.10.0"; \
    /opt/conda/bin/python -c $'import torch\nprint("torch:", torch.__version__)\nprint("cuda:", torch.version.cuda)\nprint("cuda available:", torch.cuda.is_available())'

# ===============================
# Jupyter + 常用 CLI（huggingface-cli / datasets-cli）
# - conda python：你主要跑推理/训练用
# - system python3.11：补齐 /start.sh 可能需要的 jupyter 依赖
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets; \
    /usr/local/bin/python3.11 -m ensurepip --upgrade; \
    /usr/local/bin/python3.11 -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3; \
    /usr/local/bin/python3.11 -c "import jupyter; import notebook; import jupyterlab; print('python3.11 jupyter ok')"

# ===============================
# DFlash + SGLang（默认安装）
# 关键修复点：
# - 1) 永远用 /opt/conda/bin/python 安装/验证（避免混到 system python）
# - 2) sglang 可能会回退 torch/vision/audio：装完 sglang 后，再强制把 torch 重装回 nightly cu128
# - 3) dflash 仓库不是 Python package（你已经验证：没有 setup.py/pyproject.toml，也没有 dflash/ 包）
#     所以这里只保留源码到 /opt/dflash-src，不要求 import dflash
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir -U pip setuptools wheel; \
    /opt/conda/bin/python -m pip install --no-cache-dir sglang; \
    /opt/conda/bin/python -m pip install --no-cache-dir --pre --upgrade --force-reinstall ${TORCH}; \
    /opt/conda/bin/python -m pip install --no-cache-dir --upgrade --force-reinstall "fsspec[http]==2025.10.0"; \
    rm -rf /tmp/dflash; \
    git clone --depth=1 https://github.com/z-lab/dflash.git /tmp/dflash; \
    cd /tmp/dflash; \
    if [ -f requirements.txt ]; then \
      grep -vE 'sgl-project/sglang|^sglang([<>= ].*)?$' requirements.txt > /tmp/dflash.requirements.txt || true; \
      if [ -s /tmp/dflash.requirements.txt ]; then \
        /opt/conda/bin/python -m pip install --no-cache-dir -r /tmp/dflash.requirements.txt; \
      fi; \
    fi; \
    mkdir -p /opt/dflash-src; \
    cp -a . /opt/dflash-src/; \
    /opt/conda/bin/python -c $'import sys,importlib,os\nprint("exe:",sys.executable)\nfor m in ["torch","sglang","flashinfer"]:\n  mod=importlib.import_module(m)\n  print("{}: OK  version={}".format(m, getattr(mod, "__version__", "?")))\nprint("torch.cuda.is_available:", __import__("torch").cuda.is_available())\nprint("dflash repo copied:", os.path.isdir("/opt/dflash-src"))'; \
    rm -rf /tmp/dflash

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
# User
# ===============================
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

# ===============================
# SSH config (start.sh 负责启动 sshd；这里确保配置允许密码登录)
# ===============================
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    rm -f /etc/ssh/ssh_host_*

# ===============================
# CUDA bin convenience
# ===============================
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/ || true

# ===============================
# start.sh (from buildx bake context "scripts")
# ===============================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ===============================
# nginx / branding
# ===============================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Ports (不要写行尾注释，避免某些平台解析 containerPort 失败)
# ===============================
EXPOSE 22 80 8888

# ===============================
# Entrypoint: root 直接跑 start.sh（不改你的公共 start.sh）
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]
