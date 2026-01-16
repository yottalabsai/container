# ==============================
# Base (CUDA + Ubuntu 22.04)
# ==============================
ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# Env (UTC + noninteractive)
# ==============================
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

# ==============================
# System packages
# - 包含你点名的工具：vim/jq/tree/htop/tmux/rsync
# - sshd + nginx（虽然不 expose 80，但你要它在容器里启动就给你启动）
# - python + pip：用于 huggingface-cli/datasets-cli/unsloth/jupyterlab
# - NCCL：用于 nccl-tests
# ==============================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      # base
      ca-certificates curl wget git git-lfs locales tzdata \
      # build
      build-essential pkg-config ninja-build \
      # runtime libs
      ffmpeg libgl1 libglib2.0-0 \
      # ops tools (你点名的 + 常用排障)
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof sudo \
      iproute2 iputils-ping dnsutils \
      # services
      nginx openssh-server openssh-client \
      # python
      python3 python3-pip python3-venv \
      # nccl
      libnccl2 libnccl-dev \
      # pid1
      tini \
    && git lfs install \
    && ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
    && echo "Etc/UTC" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen && update-locale \
    && rm -rf /var/lib/apt/lists/*

# ==============================
# Python CLIs (你点名的)
# - huggingface-cli 来自 huggingface_hub[cli]
# - datasets-cli 来自 datasets
# - 同时装 unsloth + jupyterlab（默认提供“Unsloth 入口服务”）
# ==============================
RUN python3 -m pip install --no-cache-dir -U pip && \
    python3 -m pip install --no-cache-dir \
      "huggingface_hub[cli]" \
      "datasets" \
      "jupyterlab" \
      "unsloth"

# ==============================
# Build nccl-tests (你点名的)
# - 可执行放到 /usr/local/bin/nccl-tests/
# ==============================
RUN git clone --depth 1 https://github.com/NVIDIA/nccl-tests.git /tmp/nccl-tests && \
    make -C /tmp/nccl-tests -j"$(nproc)" && \
    mkdir -p /usr/local/bin/nccl-tests && \
    cp -a /tmp/nccl-tests/build/* /usr/local/bin/nccl-tests/ && \
    rm -rf /tmp/nccl-tests

# ==============================
# 商用安全：SSH key-only + 禁 root 登录
# ==============================
RUN mkdir -p /var/run/sshd && \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# 创建非 root 用户（推荐商用）
ARG APP_USER=app
ARG APP_UID=1000
ARG APP_GID=1000
RUN groupadd -g ${APP_GID} ${APP_USER} && \
    useradd -m -u ${APP_UID} -g ${APP_GID} -s /bin/bash ${APP_USER} && \
    usermod -aG sudo ${APP_USER} && \
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${APP_USER} && \
    chmod 0440 /etc/sudoers.d/${APP_USER} && \
    mkdir -p /home/${APP_USER}/.ssh && \
    chmod 700 /home/${APP_USER}/.ssh && \
    chown -R ${APP_USER}:${APP_USER} /home/${APP_USER}/.ssh

# ==============================
# Runtime config
# - 只关注 SSH(22) + Unsloth 端口（这里用 Jupyter 默认端口 7861）
# - 你可以用环境变量 UNSLOTH_PORT/UNSLOTH_CMD 覆盖默认行为
# ==============================
ENV UNSLOTH_PORT=7861
# 默认把“Unsloth 服务”定义为 Jupyter（最常见用法）
ENV UNSLOTH_CMD="jupyter lab --ip=0.0.0.0 --port=${UNSLOTH_PORT} --no-browser --allow-root --NotebookApp.token='' --NotebookApp.password='' --NotebookApp.allow_origin='*'"

# ==============================
# Start script: 容器拉起就启动服务
# - 注入 PUBLIC_KEY -> /home/app/.ssh/authorized_keys
# - 启动 sshd
# - 启动 nginx（不 expose 80，但你要它“启动”我就启动）
# - 启动 UNSLOTH_CMD（默认 Jupyter）
# ==============================
RUN cat >/start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-app}"
APP_HOME="/home/${APP_USER}"

# 1) 写入 SSH 公钥（商用：只允许 key）
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  echo "[start] Installing PUBLIC_KEY for ${APP_USER}"
  install -d -m 700 -o "${APP_USER}" -g "${APP_USER}" "${APP_HOME}/.ssh"
  echo "${PUBLIC_KEY}" > "${APP_HOME}/.ssh/authorized_keys"
  chown "${APP_USER}:${APP_USER}" "${APP_HOME}/.ssh/authorized_keys"
  chmod 600 "${APP_HOME}/.ssh/authorized_keys"
else
  echo "[start] PUBLIC_KEY not set -> SSH login will fail (key-only)."
fi

# 2) 启动 sshd
echo "[start] starting sshd..."
/usr/sbin/sshd

# 3) 启动 nginx（你要求“服务拉起就启动”）
echo "[start] starting nginx..."
nginx

# 4) 启动 Unsloth 服务（默认 Jupyter）
echo "[start] starting UNSLOTH_CMD..."
echo "[start] UNSLOTH_CMD=${UNSLOTH_CMD}"
exec bash -lc "${UNSLOTH_CMD}"
EOF
RUN chmod +x /start.sh

# ==============================
# Ports (只暴露你要的两个)
# ==============================
EXPOSE 22 7861

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/start.sh"]
