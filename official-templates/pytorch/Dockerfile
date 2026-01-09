# ===============================
# Base
# ===============================
ARG BASE_IMAGE=nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ===============================
# System packages
# ===============================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git curl wget ca-certificates \
      openssh-server sudo \
      locales tzdata \
      build-essential pkg-config \
      net-tools procps iproute2 \
      vim tmux htop \
      jq tree rsync \
      unzip \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# Python 3.11 (NO deadsnakes)
# Build CPython from source for Ubuntu 22.04
# ===============================
ARG PYTHON_VERSION=3.11.9

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      # build deps for CPython
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev \
    && curl -fsSL https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz -o /tmp/Python.tgz \
    && mkdir -p /tmp/python-src \
    && tar -xzf /tmp/Python.tgz -C /tmp/python-src --strip-components=1 \
    && rm -f /tmp/Python.tgz \
    && cd /tmp/python-src \
    && ./configure --enable-optimizations --with-ensurepip=install \
    && make -j"$(nproc)" \
    && make altinstall \
    && cd / \
    && rm -rf /tmp/python-src \
    && ln -sf /usr/local/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/local/bin/python3.11 /usr/bin/python3 \
    && python -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# PyTorch 2.9 (CUDA 12.8 nightly)
# ===============================
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
RUN pip install --no-cache-dir ${TORCH}

# ===============================
# Useful Python CLIs
# huggingface-cli comes from huggingface_hub
# datasets-cli comes from datasets
# ===============================
RUN pip install --no-cache-dir \
      huggingface_hub \
      datasets

# ===============================
# Optional: NCCL tests
# NOTE: nccl-tests is not an Ubuntu default package.
# If you really want it baked-in, uncomment and ensure NCCL headers/libs exist in the base image.
# ===============================
# RUN apt-get update -y && \
#     apt-get install -y --no-install-recommends git make && \
#     git clone --depth 1 https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests && \
#     make -C /opt/nccl-tests -j"$(nproc)" && \
#     ln -sf /opt/nccl-tests/build/all_reduce_perf /usr/local/bin/all_reduce_perf && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# ===============================
# SSH basic config
# ===============================
RUN sed -i \
      -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
      -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
      /etc/ssh/sshd_config

# ===============================
# buildx bake 已经给了 contexts
# (keep your public start.sh untouched)
# ===============================
COPY --from=scripts start.sh /start.sh
RUN chmod +x /start.sh

# ===============================
# Ports
# ===============================
EXPOSE 22
EXPOSE 8888

# ===============================
# Entry
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]
