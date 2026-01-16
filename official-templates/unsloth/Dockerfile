# =========================================================
# Base image
# =========================================================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

# =========================================================
# System packages
# =========================================================
USER root
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof sudo \
      iproute2 iputils-ping dnsutils \
      nginx openssh-server openssh-client \
      libnccl2 libnccl-dev \
      python3 python3-venv python3-pip \
      software-properties-common \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Ubuntu user
# =========================================================
RUN set -eux; \
    useradd -m -s /bin/bash ubuntu; \
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu

# =========================================================
# Python 3.11
# =========================================================
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      python3.11 \
      python3.11-venv \
      python3.11-distutils; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Default Python -> 3.11
# =========================================================
RUN set -eux; \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 311; \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 311; \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.11; \
    python3.11 -m pip install --no-cache-dir -U pip setuptools wheel

# =========================================================
# Python tools (Unsloth)
# =========================================================
RUN set -eux; \
    python -m pip install --no-cache-dir \
      jupyterlab \
      notebook \
      ipykernel \
      huggingface_hub \
      datasets \
      accelerate \
      bitsandbytes \
      unsloth

# =========================================================
# Jupyter env
# =========================================================
ENV JUPYTER_PORT=8888 \
    JUPYTER_IP=0.0.0.0

# =========================================================
# nginx + README
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /home/ubuntu/.bashrc

# =========================================================
# start.sh
# =========================================================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# =========================================================
# Permissions
# =========================================================
RUN chown -R ubuntu:ubuntu /workspace /home/ubuntu

# =========================================================
# Ports
# =========================================================
EXPOSE 22 80 8888

# =========================================================
# Entrypoint
# =========================================================
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start.sh"]
