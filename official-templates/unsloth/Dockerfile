
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
RUN set -eux; \
    mkdir -p /var/lib/apt/lists/partial; \
    chmod 755 /var/lib/apt/lists /var/lib/apt/lists/partial

# ---- 实用工具 + SSH 依赖 + MPI 开发库（nccl-tests 需要）----
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
RUN set -eux; \
    pip install --no-cache-dir huggingface_hub datasets
# ---- nccl-tests（不使用 MPI，更简单）----
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
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config; \
    sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# ---- COPY 官方模板 start.sh（来自 container-template/start.sh）----
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ---- 关键兜底：平台覆盖 PID1/ENTRYPOINT 时自动启动 sshd ----
RUN cat >> /etc/bash.bashrc <<'EOS'
# Yotta: auto-start sshd when opening a shell (if platform overrides PID1)
if [ "${SSH_ENABLE:-1}" != "0" ] && command -v sshd >/dev/null 2>&1; then
  if ! pgrep -x sshd > /dev/null 2>&1; then
    sudo /usr/sbin/sshd -p 22 2>/dev/null || true
  fi
fi
EOS

# ---- Yotta 商业化元素 ----
# 1) 创建 branding 文本
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo "YottaLabs AI - Unsloth Training Platform" > /etc/yotta.txt

# 2) /etc/profile.d - 对所有登录场景生效 (login shell / ssh / exec)
RUN printf '%s\n' \
  '#!/bin/bash' \
  'cat /etc/yotta.txt 2>/dev/null || true' \
  'echo -e "\n==================================="' \
  'echo -e "Unsloth Fine-tuning Container"' \
  'echo -e "Documentation: \033[1;34mhttps://www.yottalabs.ai/\033[0m"' \
  'echo -e "===================================\n"' \
  > /etc/profile.d/yotta.sh && chmod +x /etc/profile.d/yotta.sh

# 3) /root/.bashrc - 对 root 交互式 bash 生效
RUN touch /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo '# Yotta Branding' >> /root/.bashrc && \
    echo 'cat /etc/yotta.txt 2>/dev/null || true' >> /root/.bashrc && \
    echo 'echo -e "\n==================================="' >> /root/.bashrc && \
    echo 'echo -e "Unsloth Fine-tuning Container"' >> /root/.bashrc && \
    echo 'echo -e "Documentation: \033[1;34mhttps://www.yottalabs.ai/\033[0m"' >> /root/.bashrc && \
    echo 'echo -e "===================================\n"' >> /root/.bashrc

# ---- 暴露端口 ----
EXPOSE 22 8888

# ---- 默认入口 ----
ENTRYPOINT ["/start.sh"]
