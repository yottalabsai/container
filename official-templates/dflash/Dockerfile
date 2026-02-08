ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
ARG PYTHON_VERSION="3.11.14"

# PyTorch nightly cu128（按你原来的方式）
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
# Python（统一使用 conda 的 Python，版本对齐到 PYTHON_VERSION）
# 关键修复点：
# - 不再编译 system python（那套 python 上不会有 torch/sglang，导致你 runtime import torch 失败）
# - 全局把 /usr/bin/python、/usr/bin/python3、/usr/local/bin/python3.11 指向 conda python
# - 以后所有 pip 安装都用 /opt/conda/bin/python -m pip（避免 pip 绑到 system python）
# ===============================
RUN set -eux; \
    /opt/conda/bin/conda install -y -n base -c conda-forge "python=${PYTHON_VERSION}" pip; \
    /opt/conda/bin/python -m pip install --no-cache-dir -U pip setuptools wheel; \
    ln -sf /opt/conda/bin/python /usr/local/bin/python; \
    ln -sf /opt/conda/bin/pip /usr/local/bin/pip; \
    ln -sf /opt/conda/bin/python /usr/local/bin/python3.11; \
    ln -sf /opt/conda/bin/python /usr/bin/python; \
    ln -sf /opt/conda/bin/python /usr/bin/python3; \
    python -V; \
    /opt/conda/bin/python -V

# ===============================
# PyTorch (nightly cu128) - 装在 conda python 环境里
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir --pre --upgrade --force-reinstall ${TORCH}; \
    ( /opt/conda/bin/python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
PY
    )

# ===============================
# Jupyter + 常用 CLI（huggingface-cli / datasets-cli）
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets; \
    /usr/local/bin/python3.11 -c "import jupyter; import notebook; import jupyterlab; print('python3.11 jupyter ok')"

# ===============================
# DFlash + SGLang（默认安装）
# 关键修复点：
# - 1) 永远用 /opt/conda/bin/python 安装/验证（避免混到 system python）
# - 2) sglang 可能会回退 torch/vision/audio 版本：装完 sglang 后，再强制把 torch 重装回 nightly cu128
# - 3) dflash 仓库不是 Python package（无 setup.py/pyproject.toml），只保留源码到 /opt/dflash-src，不要求 import dflash
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir -U pip setuptools wheel; \
    /opt/conda/bin/python -m pip install --no-cache-dir sglang; \
    /opt/conda/bin/python -m pip install --no-cache-dir --pre --upgrade --force-reinstall ${TORCH}; \
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
    /opt/conda/bin/python - <<'PY' \
import sys, importlib, os \
print("exe:", sys.executable) \
for m in ["torch", "sglang", "flashinfer"]: \
    try: \
        mod = importlib.import_module(m) \
        print(f"{m}: OK  version={getattr(mod,'__version__','?')}") \
    except Exception as e: \
        print(f"{m}: FAIL", repr(e)) \
print("dflash repo copied:", os.path.isdir("/opt/dflash-src")) \
PY; \
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
