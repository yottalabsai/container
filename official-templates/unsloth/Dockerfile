# ==============================
# Unsloth LLM Fine-tuning 镜像（official-templates/unsloth）
# - 底座：官方 unsloth/unsloth
# - 叠加：工具 + SSH + nccl-tests + branding
# ==============================

ARG BASE_IMAGE="unsloth/unsloth:latest"
FROM ${BASE_IMAGE} AS base

SHELL ["/bin/bash","-o","pipefail","-c"]

# ==============================
# runtime: 工具 + Branding + SSH
# ==============================
FROM base AS runtime

USER root
WORKDIR /workspace

# ---- 关键补丁：修复某些 base 镜像中 /var/lib/apt/lists 权限异常导致的 apt-get update 失败 ----
# 你遇到的：/var/lib/apt/lists/partial missing + Permission denied
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
    ; \
    mkdir -p /var/run/sshd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ---- HuggingFace CLI / Datasets CLI ----
# huggingface-cli 来自 huggingface_hub；datasets-cli 来自 datasets
RUN set -eux; \
    python3 -m pip install --no-cache-dir -U pip setuptools wheel; \
    python3 -m pip install --no-cache-dir \
      huggingface_hub \
      datasets

# ---- nccl-tests（照你原来“编译安装”的风格）----
ARG NCCL_TESTS_VERSION="v2.13.11"
ARG INSTALL_NCCL_TESTS="1"
RUN set -eux; \
    if [[ "${INSTALL_NCCL_TESTS}" == "1" ]]; then \
      rm -rf /tmp/nccl-tests; \
      git clone --depth 1 --branch "${NCCL_TESTS_VERSION}" https://github.com/NVIDIA/nccl-tests /tmp/nccl-tests; \
      make -C /tmp/nccl-tests MPI=0 -j"$(nproc)"; \
      cp -a /tmp/nccl-tests/build/* /usr/local/bin/ || true; \
      rm -rf /tmp/nccl-tests; \
    fi

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

# ---- 关键兜底：平台覆盖 PID1/ENTRYPOINT 时，你进入容器通常是打开一个 shell ----
# 这时 /start.sh 不会执行，所以在 bash 启动时自动确保 sshd 起来
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

# ---- 你的“商业化元素” ----
# 1) 更通用：/etc/profile.d 对 login shell / ssh / exec 更稳
RUN printf '%s\n' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

# 2) 按你要求：追加到 root bashrc（仅对 root 的交互 bash 生效）
RUN touch /root/.bashrc && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ---- 你要求的 chmod（允许脚本不存在：避免 build fail）----
RUN chmod +x /post_start.sh /start.sh 2>/dev/null || true

EXPOSE 22 8888

# 正常情况下走官方模板的 start.sh
# 平台若覆盖 ENTRYPOINT/CMD，上面的 bash.bashrc 兜底会在你打开 shell 时拉起 sshd
ENTRYPOINT ["/start.sh"]
