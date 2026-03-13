# ===============================
# Global ARGs (must be before first FROM if used in FROM)
# ===============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"

# ===============================
# 1) Build Go gateway binary
# ===============================
FROM golang:1.22-bookworm AS go_gateway_builder
WORKDIR /src

# Copy go.mod/go.sum first to leverage cache
COPY gateway/go.mod gateway/go.sum ./
RUN go mod download

# Then copy source code
COPY gateway/. ./

# Important: complete go.sum (to avoid the current missing go.sum entry error)
RUN go mod tidy

# Compile
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /out/gateway ./cmd/gateway


# ===============================
# 2) Main image (your existing banana template base)
# ===============================
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
# Note: use the full version number (otherwise python.org has no tarball for just "3.11")
ARG PYTHON_VERSION="3.11.14"

# PyTorch 2.9: using nightly cu128 here (following your original approach)
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"

ARG NCCL_TESTS_VERSION="v2.13.11"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=ubuntu \
    ADDR=:8080

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===============================
# Base system packages
# ===============================
# hadolint ignore=DL3008
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git acl wget curl ca-certificates bash \
      libgl1 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# Python 3.11 (build from source, with ensurepip)
# ===============================
# hadolint ignore=DL3003,DL3008,DL3013
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
# hadolint ignore=DL3013
RUN python -m pip install --no-cache-dir ${TORCH}

# ===============================
# Jupyter + common CLIs (huggingface-cli / datasets-cli)
# ===============================
# hadolint ignore=DL3013
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

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
# SSH config (start.sh is responsible for launching sshd; here we ensure the config allows password login)
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
# hadolint ignore=DL3022
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ===============================
# nginx / branding
# ===============================
# hadolint ignore=DL3022
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
# hadolint ignore=DL3022
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# hadolint ignore=DL3022
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Go model gateway
# ===============================
COPY --from=go_gateway_builder /out/gateway /opt/gateway/gateway
COPY post_start.sh /post_start.sh
RUN chmod +x /opt/gateway/gateway /post_start.sh

# ===============================
# Ports (do not add inline comments here, to avoid containerPort parsing failures on some platforms)
# ===============================
EXPOSE 22 80 8888 8080

# ===============================
# Entrypoint: root runs start.sh directly (without modifying your shared start.sh)
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]
