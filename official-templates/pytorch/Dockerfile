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
    JUPYTER_PASSWORD=ubuntu \
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
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# Python 3.11
# ===============================
ARG PYTHON_VERSION=3.11

RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      python${PYTHON_VERSION} \
      python${PYTHON_VERSION}-dev \
      python${PYTHON_VERSION}-venv \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    && python get-pip.py \
    && rm -f get-pip.py \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# PyTorch 2.9 (CUDA 12.8 nightly)
# ===============================
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir ${TORCH}

# ===============================
# SSH basic config
# ===============================
RUN sed -i \
      -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
      -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
      /etc/ssh/sshd_config

# ===============================
# buildx bake 已经给了 contexts
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
