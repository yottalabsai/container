FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JUPYTER_PORT=8888 \
    JUPYTER_IP=0.0.0.0

WORKDIR /workspace

# ===============================
# System packages
# ===============================
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

# ===============================
# User
# ===============================
RUN set -eux; \
    groupadd -g 1001 user; \
    useradd -m -u 1001 -g 1001 -s /bin/bash user; \
    echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/user; \
    chmod 0440 /etc/sudoers.d/user

# ===============================
# SSH 修复
# ===============================
RUN set -eux; \
    mkdir -p /run/sshd; \
    chmod 0755 /run/sshd; \
    sed -i 's/^#\?Port .*/Port 22/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config; \
    echo "AllowUsers user" >> /etc/ssh/sshd_config

# ===============================
# Python tools (no conda)
# ===============================
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel; \
    python3 -m pip install --no-cache-dir \
      jupyterlab notebook ipykernel \
      huggingface_hub datasets accelerate bitsandbytes unsloth

# ===============================
# Branding
# ===============================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /home/user/.bashrc

# ===============================
# Permissions
# ===============================
RUN chown -R user:user /workspace /home/user

# ===============================
# Ports
# ===============================
EXPOSE 22 8888

# ===============================
# Entrypoint
# ===============================
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-lc", "\
set -e; \
/usr/sbin/sshd; \
nginx || true; \
mkdir -p /home/user/.jupyter; \
if [ -n \"${JUPYTER_PASSWORD:-}\" ]; then \
python3 - <<'PY'\n\
from jupyter_server.auth import passwd\n\
import os\n\
print('c.ServerApp.password = %r' % passwd(os.environ['JUPYTER_PASSWORD']))\n\
print('c.ServerApp.token = \"\"')\n\
PY \
> /home/user/.jupyter/jupyter_server_config.py; \
chown -R user:user /home/user/.jupyter; \
fi; \
exec sudo -u user -E jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --ServerApp.allow_remote_access=True \
  --ServerApp.root_dir=/workspace \
"]
