# =========================================================
# Base image
# =========================================================
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    JUPYTER_IP=0.0.0.0 \
    JUPYTER_PORT=8888

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
      software-properties-common \
      python3 python3-venv python3-pip \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Ubuntu user (platform user)
# =========================================================
RUN set -eux; \
    useradd -m -s /bin/bash ubuntu; \
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu; \
    passwd -l ubuntu || true

# =========================================================
# Python 3.11 (no conda)
# =========================================================
RUN set -eux; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-distutils; \
    rm -rf /var/lib/apt/lists/*

# Default python -> 3.11 + pip
RUN set -eux; \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.11 311; \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 311; \
    curl -fSL --retry 10 --retry-all-errors --retry-delay 2 https://bootstrap.pypa.io/get-pip.py | python3.11; \
    python3.11 -m pip install --no-cache-dir -U pip setuptools wheel

# Python tools (Unsloth + Jupyter)
RUN set -eux; \
    python -m pip install --no-cache-dir \
      jupyterlab notebook ipykernel \
      huggingface_hub datasets accelerate bitsandbytes unsloth

# =========================================================
# nginx + README (80)
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
# SSH hardening (still starts on 22; key-based by default)
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config; \
    printf "\nAllowUsers ubuntu\n" >> /etc/ssh/sshd_config

# =========================================================
# Permissions
# =========================================================
RUN chown -R ubuntu:ubuntu /workspace /home/ubuntu

# =========================================================
# Ports
# =========================================================
EXPOSE 22 80 8888

# =========================================================
# Entrypoint: start sshd + nginx + jupyter (auto)
# - JUPYTER_PASSWORD is supported (set at run time)
# =========================================================
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-lc", "\
set -euo pipefail; \
ssh-keygen -A >/dev/null 2>&1 || true; \
/usr/sbin/sshd; \
nginx; \
mkdir -p /home/ubuntu/.jupyter; \
if [ -n \"${JUPYTER_PASSWORD:-}\" ]; then \
  python - <<'PY'\n\
import os\n\
from jupyter_server.auth import passwd\n\
pw = os.environ.get('JUPYTER_PASSWORD','')\n\
print('c.ServerApp.password = %r' % passwd(pw))\n\
print('c.ServerApp.token = \"\"')\n\
PY \
  > /home/ubuntu/.jupyter/jupyter_server_config.py; \
  chown -R ubuntu:ubuntu /home/ubuntu/.jupyter; \
fi; \
exec sudo -u ubuntu -E jupyter lab \
  --ip=${JUPYTER_IP} \
  --port=${JUPYTER_PORT} \
  --no-browser \
  --ServerApp.allow_origin='*' \
  --ServerApp.allow_remote_access=True \
  --ServerApp.root_dir=/workspace \
"]

