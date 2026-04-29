# ===============================
# Build args
# ===============================
ARG PYTHON_VERSION="3.12.11"
ARG NCCL_TESTS_VERSION="v2.13.11"

# ===============================
# logo + scripts + proxy stages
# ===============================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY updated_start.sh updated_start.sh

# nginx config / landing page (keep as its own stage to match existing COPY --from=proxy)
FROM scratch AS proxy
# These two files must exist in the build context; adjust paths if not at root
COPY nginx.conf nginx.conf
COPY readme.html readme.html

# =========================================================
# Base image
# =========================================================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

# Re-declare ARGs after FROM so they are available in this stage
ARG PYTHON_VERSION="3.12.11"
ARG NCCL_TESTS_VERSION="v2.13.11"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PATH=/opt/conda/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=yotta

WORKDIR /workspace

# =========================================================
# System packages
# =========================================================
USER root
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs locales tzdata \
      build-essential pkg-config ninja-build cmake \
      ffmpeg libgl1 libglib2.0-0 \
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof sudo \
      iproute2 iputils-ping dnsutils \
      nginx openssh-server openssh-client \
      libnccl2 libnccl-dev \
      software-properties-common \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libffi-dev libncursesw5-dev xz-utils tk-dev uuid-dev liblzma-dev \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    mkdir -p /var/run/sshd /var/log/supervisor; \
    chmod 700 /var/run/sshd /var/log/supervisor; \
    chmod 755 /var/log; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Workspace initialization
# =========================================================
RUN mkdir -p /workspace && chmod 777 /workspace /root

# =========================================================
# Python 3.12 (build from source, with ensurepip)
# =========================================================
RUN set -eux; \
    PY_MM="3.12"; \
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
    python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# =========================================================
# SkyRL + fsdp backend (from GitHub, using uv for override support)
# =========================================================
RUN set -eux; \
    pip install --no-cache-dir uv; \
    git clone --depth 1 https://github.com/NovaSky-AI/SkyRL.git /opt/skyrl; \
    cd /opt/skyrl; \
    printf '%s\n' \
      'transformers>=5.0.0,<=5.3.0' \
      'nvidia-resiliency-ext; sys_platform == "never"' \
      'mamba-ssm; sys_platform == "never"' \
      'causal-conv1d; sys_platform == "never"' \
      > /tmp/overrides.txt; \
    uv pip install --system --no-cache \
      --index-strategy unsafe-best-match \
      --extra-index-url https://download.pytorch.org/whl/cu128 \
      --extra-index-url https://flashinfer.ai/whl/cu128 \
      --override /tmp/overrides.txt \
      -e ".[fsdp]"; \
    rm -f /tmp/overrides.txt; \
    rm -rf /opt/skyrl/.git

# =========================================================
# Additional Python tools (Jupyter, monitoring, etc.)
# =========================================================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets notebook \
      tensorboard wandb \
      bitsandbytes

# =========================================================
# nccl-tests
# =========================================================
RUN set -eux; \
    git clone --depth 1 https://github.com/NVIDIA/nccl-tests.git /tmp/nccl-tests; \
    make -C /tmp/nccl-tests -j"$(nproc)"; \
    mkdir -p /usr/local/bin/nccl-tests; \
    cp -a /tmp/nccl-tests/build/* /usr/local/bin/nccl-tests/; \
    rm -rf /tmp/nccl-tests

# =========================================================
# SSH hardening (platform may override anyway)
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# =========================================================
# nginx + README (optional)
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# start.sh (must be kept as-is)
# =========================================================
COPY --from=scripts updated_start.sh /updated_start.sh
RUN chmod 755 /updated_start.sh && \
    sed -i 's/\r$//' /updated_start.sh

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc || true

COPY SkyRL_Demo.ipynb /workspace/

# =========================================================
# Permissions (ensure /workspace is writable)
# =========================================================
RUN chown -R root:root /workspace || true

# =========================================================
# Ports
# =========================================================
EXPOSE 22 80 8888 6006

# =========================================================
# Entrypoint: root runs updated_start.sh with explicit bash
# =========================================================
USER root
WORKDIR /root
CMD ["/bin/bash", "-c", "exec /bin/bash /updated_start.sh"]
