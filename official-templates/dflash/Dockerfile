ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
# Note: use the full version number (python.org has no tarball for short forms like '3.11')
ARG PYTHON_VERSION="3.11.14"

# PyTorch: pinned to stable torch==2.9.1 required by sglang/sgl-kernel (CUDA 12.8 wheels)
# Note: do not use nightly; pip will warn about dependency conflicts and may cause ABI/extension issues
ARG TORCH_INDEX_URL="https://download.pytorch.org/whl/cu128"
ARG TORCH="torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1"

ARG SGLANG_VERSION="0.5.8.post1"
ARG NCCL_TESTS_VERSION="v2.13.11"

# Optional: controlled by bake.hcl — set INSTALL_DFLASH=1 to clone the dflash source
ARG INSTALL_DFLASH="0"
ARG DFLASH_REPO="https://github.com/z-lab/dflash.git"
ARG DFLASH_REF="main"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/opt/conda/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    CUDA_HOME=/usr/local/cuda

# ===============================
# Persist CUDA env (fixes sglang / flashinfer JIT compilation failing to find cuda_runtime.h)
# Avoid heredoc to prevent Dockerfile parser issues
# ===============================
RUN set -eux; \
    printf '%s\n' \
'#!/usr/bin/env bash' \
'export CUDA_HOME=/usr/local/cuda' \
'export CUDA_PATH=/usr/local/cuda' \
'export PATH=$CUDA_HOME/bin:$PATH' \
'export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH}' \
'' \
'# Explicitly add include paths so nvcc / gcc can find cuda_runtime.h' \
'export CPATH=$CUDA_HOME/include:${CPATH}' \
'export C_INCLUDE_PATH=$CUDA_HOME/include:${C_INCLUDE_PATH}' \
'export CPLUS_INCLUDE_PATH=$CUDA_HOME/include:${CPLUS_INCLUDE_PATH}' \
    > /etc/profile.d/10-cuda-env.sh; \
    chmod 644 /etc/profile.d/10-cuda-env.sh; \
    echo "/usr/local/cuda/lib64" > /etc/ld.so.conf.d/cuda.conf; \
    ldconfig

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===============================
# APT helper (NVIDIA repo occasionally has mirror sync issues: Packages.gz size/hash mismatch)
# - Use retries + timeout + a second update attempt for robustness
# ===============================
RUN set -eux; \
    apt-get update -y \
      -o Acquire::Retries=5 \
      -o Acquire::http::Timeout=30 \
      -o Acquire::https::Timeout=30 \
    || (sleep 8 && apt-get update -y \
      -o Acquire::Retries=5 \
      -o Acquire::http::Timeout=30 \
      -o Acquire::https::Timeout=30)

# ===============================
# Base system packages (+ ninja + libnuma1)
# ===============================
RUN set -eux; \
    apt-get install -y --no-install-recommends \
      git acl wget curl ca-certificates bash \
      libgl1 software-properties-common \
      locales tzdata libnuma1 \
      openssh-server nginx sudo \
      tmux vim zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd iproute2 \
      build-essential pkg-config ninja-build \
    ; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    mkdir -p /var/run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ===============================
# uv (Astral) - Python package manager
# - Install to /usr/local/bin
# - Avoids modifying shell profile (suitable for containers/CI)
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
# - Keep system python3.11 available for /start.sh / jupyter compatibility
# - Do not point /usr/bin/python to system python to avoid runtime using a Python without torch installed
# ===============================
RUN set -eux; \
    apt-get update -y \
      -o Acquire::Retries=5 \
      -o Acquire::http::Timeout=30 \
      -o Acquire::https::Timeout=30 \
    || (sleep 8 && apt-get update -y \
      -o Acquire::Retries=5 \
      -o Acquire::http::Timeout=30 \
      -o Acquire::https::Timeout=30); \
    apt-get install -y --no-install-recommends \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev \
    ; \
    curl -fSL --retry 10 --retry-delay 2 --retry-all-errors \
      "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" \
      -o /tmp/Python.tgz; \
    mkdir -p /tmp/python-src; \
    tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1; \
    rm -f /tmp/Python.tgz; \
    cd /tmp/python-src; \
    ./configure --enable-optimizations --with-ensurepip=install; \
    make -j"$(nproc)"; \
    make altinstall; \
    cd /; \
    rm -rf /tmp/python-src; \
    /usr/local/bin/python3.11 -m pip install --no-cache-dir --upgrade pip setuptools wheel; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ===============================
# Key fix: make python/pip default to conda python
# - Prevents start.sh / login shell from falling back to system python when PATH lacks /opt/conda/bin
# - System python remains available at /usr/local/bin/python3.11
# ===============================
RUN set -eux; \
    ln -sf /opt/conda/bin/python /usr/bin/python; \
    ln -sf /opt/conda/bin/python /usr/bin/python3; \
    ln -sf /opt/conda/bin/python /usr/local/bin/python; \
    echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/00-conda-path.sh; \
    chmod 644 /etc/profile.d/00-conda-path.sh

# ===============================
# PyTorch (stable cu128, pinned) — always install via conda python
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir -U pip setuptools wheel; \
    /opt/conda/bin/python -m pip install --no-cache-dir --upgrade --force-reinstall \
      --index-url "${TORCH_INDEX_URL}" ${TORCH}; \
    /opt/conda/bin/python -m pip install --no-cache-dir --upgrade --force-reinstall "fsspec[http]==2025.10.0"; \
    /opt/conda/bin/python -c $'import torch\nprint("torch:", torch.__version__)\nprint("cuda:", torch.version.cuda)\nprint("cuda available:", torch.cuda.is_available())'

# ===============================
# Jupyter + common CLI tools (huggingface-cli / datasets-cli)
# - conda python: used for inference/training
# - system python3.11: provides jupyter deps that /start.sh may require
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
# SGLang (installed by default)
# ===============================
RUN set -eux; \
    /opt/conda/bin/python -m pip install --no-cache-dir -U pip setuptools wheel; \
    /opt/conda/bin/python -m pip install --no-cache-dir "sglang==${SGLANG_VERSION}"; \
    /opt/conda/bin/python -m pip check

# ===============================
# DFlash (optional: controlled by INSTALL_DFLASH)
# - dflash repo is not a Python package (no setup.py/pyproject.toml, no dflash/ package)
# - Source is cloned to /opt/dflash-src; dependencies from requirements.txt are installed (sglang entries filtered out)
# ===============================
RUN set -eux; \
    if [ "${INSTALL_DFLASH}" = "1" ]; then \
      echo "[dflash] cloning ${DFLASH_REPO} ref=${DFLASH_REF}"; \
      rm -rf /tmp/dflash; \
      git clone --depth=1 --branch "${DFLASH_REF}" "${DFLASH_REPO}" /tmp/dflash; \
      cd /tmp/dflash; \
      if [ -f requirements.txt ]; then \
        grep -vE 'sgl-project/sglang|^sglang([<>= ].*)?$' requirements.txt > /tmp/dflash.requirements.txt || true; \
        if [ -s /tmp/dflash.requirements.txt ]; then \
          /opt/conda/bin/python -m pip install --no-cache-dir -r /tmp/dflash.requirements.txt; \
        fi; \
      fi; \
      mkdir -p /opt/dflash-src; \
      cp -a . /opt/dflash-src/; \
      /opt/conda/bin/python -c $'import sys,importlib,os\nprint("exe:",sys.executable)\nfor m in ["torch","sglang"]:\n  mod=importlib.import_module(m)\n  print("{}: OK  version={}".format(m, getattr(mod, "__version__", "?")))\nprint("torch.cuda.is_available:", __import__("torch").cuda.is_available())\nprint("dflash repo copied:", os.path.isdir("/opt/dflash-src"))'; \
      /opt/conda/bin/python -m pip check; \
      rm -rf /tmp/dflash; \
    else \
      echo "[dflash] INSTALL_DFLASH!=1, skip"; \
    fi

# ===============================
# SGLang minimal smoke test script (Qwen 7B: start server + send one request)
# ===============================
RUN set -eux; \
    cat >/usr/local/bin/sglang_basic_smoke.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

MODEL=${1:-Qwen/Qwen2.5-7B-Instruct}
HOST=${HOST:-0.0.0.0}
PORT=${PORT:-30000}

echo "[smoke] model=$MODEL host=$HOST port=$PORT"

/opt/conda/bin/python -m sglang.launch_server \
  --model-path "$MODEL" \
  --host "$HOST" \
  --port "$PORT" \
  --mem-fraction-static 0.9 &
PID=$!
trap 'echo "[smoke] stopping pid=$PID"; kill $PID || true' EXIT

for i in $(seq 1 60); do
  if curl -s "http://127.0.0.1:${PORT}/v1/models" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[smoke] server up, sending request..."
curl -s "http://127.0.0.1:${PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello in one short sentence.\"}],\"max_tokens\":32,\"temperature\":0.2}" | head
echo
echo "[smoke] OK"
SH

RUN chmod 755 /usr/local/bin/sglang_basic_smoke.sh


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
# SSH config (start.sh handles sshd startup; ensure password login is allowed)
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
# entrypoint wrapper: start sglang then exec /start.sh
# ===============================
RUN set -eux; \
  cat > /entrypoint.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] starting..."

export CUDA_HOME=/usr/local/cuda
export CUDA_PATH=/usr/local/cuda
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"
export CPATH="$CUDA_HOME/include:${CPATH:-}"
export C_INCLUDE_PATH="$CUDA_HOME/include:${C_INCLUDE_PATH:-}"
export CPLUS_INCLUDE_PATH="$CUDA_HOME/include:${CPLUS_INCLUDE_PATH:-}"

rm -rf /root/.cache/flashinfer 2>/dev/null || true

LOG_DIR="${SGLANG_LOG_DIR:-/workspace/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/sglang.log"

if ! ps -ef | grep -E "python .*sglang\.launch_server" | grep -v grep >/dev/null; then
  echo "[entrypoint] launching sglang..."
  nohup /opt/conda/bin/python -m sglang.launch_server \
    --model-path "${SGLANG_MODEL:-Qwen/Qwen2.5-7B-Instruct}" \
    --host 0.0.0.0 \
    --port "${SGLANG_PORT:-30000}" \
    --mem-fraction-static "${SGLANG_MEM_FRACTION_STATIC:-0.9}" \
    >"$LOG_FILE" 2>&1 &
  sleep 2
fi

echo "[entrypoint] exec start.sh"
exec /start.sh
SH
RUN chmod 755 /entrypoint.sh && sed -i 's/\r$//' /entrypoint.sh

# ===============================
# nginx / branding
# ===============================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Ports (no inline comments — some platforms fail to parse containerPort with trailing comments)
# ===============================
EXPOSE 22 80 8888 30000

# ===============================
# Entrypoint: run entrypoint.sh as root (entrypoint.sh execs /start.sh internally)
# ===============================
USER root
WORKDIR /root
ENTRYPOINT ["/bin/bash","-lc","exec /entrypoint.sh"]
