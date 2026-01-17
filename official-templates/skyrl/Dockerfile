# ===============================
# logo + scripts + proxy stages
# ===============================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY container-template/start.sh start.sh

# nginx config / landing page (keep as its own stage to match existing COPY --from=proxy)
FROM scratch AS proxy
# 你可以把 nginx.conf / readme.html 放在构建上下文根目录；
# 或者放在 container-template/ 下面（二选一，按你仓库实际路径改）。
COPY nginx.conf nginx.conf
COPY readme.html readme.html

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
    JUPYTER_PASSWORD=ubuntu

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
      python3 python3-venv python3-pip \
      software-properties-common \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Users: ubuntu (compat)
# =========================================================
RUN set -eux; \
    useradd -ms /bin/bash ubuntu; \
    usermod -aG sudo ubuntu; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    echo "ubuntu:ubuntu" | chpasswd

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
# Python tools (SkyRL / Unsloth)
# =========================================================
RUN set -eux; \
    python -m pip install --no-cache-dir \
      ray[default,data,train,tune,serve]==2.51.1 \
      torch>=2.0.0 \
      transformers \
      datasets \
      accelerate \
      tensorboard \
      wandb \
      jupyterlab \
      ipywidgets \
      notebook \
      huggingface_hub \
      bitsandbytes \
      unsloth

# =========================================================
# Megatron-LM
# =========================================================
RUN git clone --depth 1 https://github.com/NVIDIA/Megatron-LM.git /opt/megatron-lm && \
    pip install -e /opt/megatron-lm

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
# SSH hardening
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# =========================================================
# nginx + README
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# start.sh (必须原样保留)
# =========================================================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /home/ubuntu/.bashrc

# =========================================================
# Entrypoint wrapper
# - 关键点：把 tensorboard 放到 ENTRYPOINT 里，避免平台覆盖 CMD 导致 6006 不起
# - 不修改 /start.sh，只是在启动时尝试执行它（如果存在）
# =========================================================
RUN set -eux; \
  cat > /entrypoint.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail

# 起 SSH / nginx（不阻塞）
/usr/sbin/sshd || true
nginx || true

# 如果平台依赖 /start.sh，这里也尝试执行（不修改它）
if [ -x /start.sh ]; then
  /start.sh &
fi

# 起 TensorBoard（后台）
nohup tensorboard --logdir=/workspace --port=6006 --host=0.0.0.0 > /tmp/tensorboard.log 2>&1 &

# 默认启动 JupyterLab；如果外部传了命令，就执行外部命令
JUSER=ubuntu
export HOME=/home/${JUSER}
export JUPYTER_RUNTIME_DIR=$HOME/.local/share/jupyter/runtime
mkdir -p $HOME/.jupyter $JUPYTER_RUNTIME_DIR
chown -R $JUSER:$JUSER $HOME/.jupyter $HOME/.local /workspace || true

if [ "$#" -gt 0 ]; then
  exec "$@"
else
  exec sudo -u ${JUSER} -H bash -lc "jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --ServerApp.allow_remote_access=True \
    --ServerApp.root_dir=/workspace \
    --ServerApp.password='' \
    --ServerApp.token='' \
    --ServerApp.allow_password=False"
fi
SH
RUN chmod +x /entrypoint.sh


# =========================================================
# Permissions
# =========================================================
RUN chown -R ubuntu:ubuntu /workspace /home/ubuntu

# =========================================================
# Ports
# =========================================================
EXPOSE 22 80 8888 6006

# =========================================================
# Entrypoint
# =========================================================
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD []
