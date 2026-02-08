ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
ARG PYTHON_VERSION="3.11.14"

# PyTorch 2.9：nightly cu128（按你原来的方式）
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
    && ./configure --enable-optimizations --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && cd / \
    && rm -rf /tmp/python-src \
    && ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python \
    && ln -sf "/usr/local/bin/python${PY_MM}" /usr/bin/python3 \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# PyTorch (nightly cu128)
# ===============================
RUN python -m pip install --no-cache-dir ${TORCH}

# ===============================
# Jupyter + 常用 CLI（huggingface-cli / datasets-cli）
# ===============================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

# ===============================
# DFlash + SGLang（默认安装）
# 关键修复点：
# - 1) sglang 的 extra 'srt' 在你日志里显示“不存在”，所以直接装 sglang（避免误导）
# - 2) sglang 会强依赖/回退 torch==2.9.1 等，安装完后再把 torch/vision/audio 重装回 nightly cu128（保证最终一致）
# - 3) uv pip 默认要求 venv，你这边不想引入 venv，所以 dflash 这块改用 python -m pip 装 requirements（最稳）
# ===============================
RUN set -eux; \
    python -m pip install --no-cache-dir -U pip setuptools wheel; \
    # 先装发布版 sglang（避免 dflash/requirements.txt pin 到某个 PR 导致 flashinfer/cutlass 等被降级） \
    python -m pip install --no-cache-dir sglang; \
    # 把 PyTorch 重装回 nightly cu128（sglang 可能会回退 torch/vision/audio 版本） \
    python -m pip install --no-cache-dir ${TORCH}; \
    rm -rf /tmp/dflash; \
    git clone --depth=1 https://github.com/z-lab/dflash.git /tmp/dflash; \
    cd /tmp/dflash; \
    # requirements.txt 里如果包含 sglang 的 git+...（PR ref），会把已装好的 sglang/flashinfer/cutlass 回退；这里直接过滤掉那一行 \
    if [ -f requirements.txt ]; then \
      grep -vE 'sgl-project/sglang|^sglang([<>= ].*)?$' requirements.txt > /tmp/dflash.requirements.txt || true; \
      if [ -s /tmp/dflash.requirements.txt ]; then \
        python -m pip install --no-cache-dir -r /tmp/dflash.requirements.txt; \
      fi; \
    fi; \
    # dflash 仓库不一定在根目录提供 setup.py/pyproject.toml，做一个“找得到就装”的自适应安装 \
    pkg_dir=""; \
    for d in . python ./python ./bindings/python ./src/python; do \
      if [ -f "$d/pyproject.toml" ] || [ -f "$d/setup.py" ] || [ -f "$d/setup.cfg" ]; then pkg_dir="$d"; break; fi; \
    done; \
    if [ -z "$pkg_dir" ]; then \
      pkg_dir="$(find . -maxdepth 5 -type f \( -name pyproject.toml -o -name setup.py -o -name setup.cfg \) -print -quit | xargs -r dirname || true)"; \
    fi; \
    if [ -n "$pkg_dir" ]; then \
      python -m pip install --no-cache-dir -e "$pkg_dir"; \
    else \
      # dflash 可能只提供 CUDA/C++ 源码，不一定带可安装的 Python 包；这里不强制失败。\
      # 把源码留在 /opt/dflash-src，供运行时或后续编译/调试使用。\
      mkdir -p /opt/dflash-src; \
      cp -a . /opt/dflash-src/; \
      # 兼容：如果仓库里确实有 dflash/ 纯 Python 包，则用 .pth 暴露到 sys.path\
      if [ -d "./dflash" ] && [ -f "./dflash/__init__.py" ]; then \
        mkdir -p /opt/dflash && cp -a ./dflash /opt/dflash/; \
        echo "/opt/dflash" > /opt/conda/lib/python3.11/site-packages/dflash.pth; \
      fi; \
    fi; \
    python -c "import importlib, sglang; print('sglang OK'); try: importlib.import_module('dflash'); print('dflash import OK'); except Exception as e: print('dflash not importable (ok):', e)"; \
    rm -rf /tmp/dflash

# ===============================
# Patch: ensure python3.11 has Jupyter (required by /start.sh)
# 不改你现有的 python -m pip 安装逻辑，仅补齐 python3.11 环境
# ===============================
RUN /usr/local/bin/python3.11 -m ensurepip --upgrade && \
    /usr/local/bin/python3.11 -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3

# 构建期断言：避免推坏镜像
RUN /usr/local/bin/python3.11 -c "import jupyter; import notebook; import jupyterlab; print('python3.11 jupyter ok')"

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
