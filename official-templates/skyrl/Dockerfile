# ==============================
# SkyRL Reinforcement Learning 镜像（official-templates/skyrl）
# - 底座：官方 skypilot/skypilot
# - 叠加：Ray + 工具 + SSH + branding
# ==============================

ARG BASE_IMAGE="skypilot/skypilot:latest"
FROM ${BASE_IMAGE} AS base

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# runtime: Ray + 工具 + Branding + SSH
# ==============================
FROM base AS runtime

USER root
WORKDIR /workspace

# ---- 关键补丁：修复某些 base 镜像中 /var/lib/apt/lists 权限异常导致的 apt-get update 失败 ----
RUN set -eux; \
    mkdir -p /var/lib/apt/lists/partial; \
    chmod -R 755 /var/lib/apt/lists || true

# ---- 实用工具 + SSH 依赖 ----
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

# ---- HuggingFace CLI / Datasets CLI ----
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel; \
    python3 -m pip install --no-cache-dir \
      huggingface_hub \
      datasets

# ---- Ray RL 依赖 ----
RUN set -eux; \
    python3 -m pip install --no-cache-dir \
      'ray[default,rllib]' \
      gymnasium \
      tensorboard \
      wandb \
      mlflow \
      stable-baselines3

# ---- SSH 配置：默认更安全（推荐商用：key-only）----
RUN set -eux; \
    sed -i \
      -e 's@^#\?PermitRootLogin .*@PermitRootLogin prohibit-password@g' \
      -e 's@^#\?PasswordAuthentication .*@PasswordAuthentication no@g' \
      -e 's@^#\?PubkeyAuthentication .*@PubkeyAuthentication yes@g' \
      -e 's@^#\?UsePAM .*@UsePAM yes@g' \
      /etc/ssh/sshd_config

# ---- COPY 官方模板 start.sh（来自 container-template/start.sh）----
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ---- 关键兜底：平台覆盖 PID1/ENTRYPOINT 时自动启动 sshd ----
RUN cat >> /etc/bash.bashrc <<'EOS'

# ---- Yotta: auto-start sshd when a shell is opened (platform may override PID1) ----
if [ "${SSH_ENABLE:-1}" != "0" ] && command -v sshd >/dev/null 2>&1; then
  if ! pgrep -x sshd >/dev/null 2>&1; then
    mkdir -p /var/run/sshd
    [ -f /etc/ssh/ssh_host_rsa_key ] || ssh-keygen -A >/dev/null 2>&1 || true
    /usr/sbin/sshd -p "${SSH_PORT:-22}" >/dev/null 2>&1 || true
  fi
fi
# ------------------------------------------------------------------------------------
EOS

# ---- Yotta 商业化元素 ----
# 1) 创建 branding 文本
RUN set -eux; \
    echo "YottaLabs AI - SkyRL Training Platform" > /etc/yotta.txt; \
    cat /etc/yotta.txt

# 2) /etc/profile.d - 对所有登录场景生效
RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

# 3) 追加到 root bashrc（仅对 root 的交互 bash 生效）
RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt 2>/dev/null || true' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ---- 允许脚本不存在：避免 build fail ----
RUN chmod +x /post_start.sh /start.sh 2>/dev/null || true

# ---- 暴露端口 ----
EXPOSE 22 6379 8265 8888

# ---- 默认入口 ----
ENTRYPOINT ["/start.sh"]

