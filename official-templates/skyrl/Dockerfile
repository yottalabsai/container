# ==============================
# SkyRL Reinforcement Learning 镜像（official-templates/skyrl）
# - 底座：官方 skypilot/skypilot
# - 叠加：Ray + 工具 + SSH + Nginx + branding
# ==============================

ARG BASE_IMAGE="novaskyai/skyrl-train-ray-2.51.1-py3.12-cu12.8"
FROM ${BASE_IMAGE} AS base

# ---- 环境变量配置 ----
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=ubuntu \
    JUPYTER_ENABLE=1

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# runtime: Ray + 工具 + Branding + SSH
# ==============================
FROM base AS runtime

USER root
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ---- 关键补丁：修复某些 base 镜像中 /var/lib/apt/lists 权限异常导致的 apt-get update 失败 ----
RUN set -eux; \
    mkdir -p /var/lib/apt/lists/partial; \
    chmod -R 755 /var/lib/apt/lists || true

# ---- 实用工具 + SSH 依赖 + Nginx ----
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
      vim \
      htop \
      tmux \
      nano \
      iputils-ping \
      lsof \
      tree \
      jq \
      net-tools \
      netcat-openbsd \
      procps \
      iproute2 \
      rsync \
      openssh-server \
      sudo \
      ca-certificates \
      curl \
      wget \
      git \
      build-essential \
      pkg-config \
      nginx \
    ; \
    mkdir -p /var/run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ---- Python 依赖更新 ----
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel

# ---- Jupyter + 常用 CLI ----
RUN python3 -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

# ---- Ray RL 依赖 ----
RUN set -eux; \
    python3 -m pip install --no-cache-dir \
      'ray[default,rllib]' \
      gymnasium \
      tensorboard \
      wandb \
      mlflow \
      stable-baselines3

# ---- 动态检测 Python 版本并创建 python3.11 符号链接（兼容 start.sh）----
RUN set -eux; \
    PYTHON_BIN=$(which python3); \
    echo "Detected Python: $PYTHON_BIN"; \
    ln -sf "$PYTHON_BIN" /usr/bin/python3.11; \
    python3.11 --version


# ---- SSH 配置：默认更安全（推荐商用：key-only）----
RUN set -eux; \
    sed -i \
      -e 's@^#\?PermitRootLogin .*@PermitRootLogin prohibit-password@g' \
      -e 's@^#\?PasswordAuthentication .*@PasswordAuthentication no@g' \
      -e 's@^#\?PubkeyAuthentication .*@PubkeyAuthentication yes@g' \
      -e 's@^#\?UsePAM .*@UsePAM yes@g' \
      /etc/ssh/sshd_config

RUN cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        # 如果 URL 中没有查询参数,自动添加 token
        if (\$args = "") {
            set \$args "token=${JUPYTER_PASSWORD}";
        }

        proxy_pass http://127.0.0.1:8888;
        proxy_set_header Host \$host;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF


# ---- COPY 官方模板 start.sh（来自 container-template/start.sh）----
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ---- 关键兜底：平台覆盖 PID1/ENTRYPOINT 时自动启动 sshd + nginx ----
RUN cat >> /etc/bash.bashrc <<'EOS'

# ---- Yotta: auto-start services when a shell is opened (platform may override PID1) ----
if [ "${SSH_ENABLE:-1}" != "0" ] && command -v sshd >/dev/null 2>&1; then
  if ! pgrep -x sshd >/dev/null 2>&1; then
    mkdir -p /var/run/sshd
    [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A >/dev/null 2>&1 || true
    /usr/sbin/sshd -p "${SSH_PORT:-22}" >/dev/null 2>&1 || true
  fi
fi

# Auto-start nginx
if command -v nginx >/dev/null 2>&1; then
  if ! pgrep -x nginx >/dev/null 2>&1; then
    service nginx start >/dev/null 2>&1 || true
  fi
fi
# ------------------------------------------------------------------------------------
EOS

# ---- Yotta 商业化元素 ----
RUN set -eux; \
    echo "YottaLabs AI - SkyRL Training Platform" > /etc/yotta.txt; \
    cat /etc/yotta.txt

RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt 2>/dev/null || true' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

RUN chmod +x /post_start.sh /start.sh 2>/dev/null || true

# ---- 暴露端口 ----
EXPOSE 22 80 6379 8265 8888

USER root
WORKDIR /root

# ---- 创建 ubuntu 用户（修复 chown: invalid user 错误）----
RUN useradd -m -s /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \    
    chmod 0440 /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

ENTRYPOINT ["/start.sh"]

