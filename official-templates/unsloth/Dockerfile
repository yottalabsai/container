# =========================================================
# Base: Official Unsloth image (includes /workspace/unsloth-notebooks)
# =========================================================
FROM unsloth/unsloth AS base

# =========================================================
# Final image
# =========================================================
FROM base

# -------------------------------
# Environment
# -------------------------------
# 让 /opt/venv/bin 在所有用户的 PATH 前面（解决 sudo -u unsloth 找不到 jupyter）
ENV PATH="/opt/venv/bin:${PATH}"

# 你只要求 JUPYTER_PASSWORD 确保存在（值可被平台/运行时覆盖）
ENV JUPYTER_PASSWORD="unsloth"

# -------------------------------
# System tools you asked for
# vim, jq, tree, htop, tmux, rsync, etc.
# -------------------------------
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      sudo openssh-server \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      tini; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Python CLIs (huggingface-cli, datasets-cli)
# 注意：我们用 venv 的 pip 安装，确保 CLI 进 /opt/venv/bin
# -------------------------------
RUN set -eux; \
    /opt/venv/bin/python -m pip install --no-cache-dir -U pip; \
    /opt/venv/bin/python -m pip install --no-cache-dir \
      "huggingface_hub[cli]" \
      "datasets"

# -------------------------------
# Your start.sh (MUST NOT MODIFY CONTENT) + mode only
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# Your branding snippet (你要求必须原样)
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# Optional: create ubuntu user (some platforms expect it)
# 不会影响官方 unsloth 用户；只是补一个 ubuntu 以兼容你平台/习惯
# -------------------------------
RUN set -eux; \
    if ! id ubuntu >/dev/null 2>&1; then \
      useradd -m -s /bin/bash ubuntu; \
      usermod -aG sudo ubuntu; \
      echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu; \
      chmod 0440 /etc/sudoers.d/90-ubuntu; \
    fi; \
    mkdir -p /workspace/work; \
    chown -R ubuntu:ubuntu /workspace || true

# -------------------------------
# CRITICAL: Platform injects command like:
#   /usr/sbin/sshd -D && /start.sh
# -D blocks forever -> /start.sh never runs
# Solution: wrap /usr/sbin/sshd so "-D" daemonizes then exits 0
# NO heredoc (builder incompatible) -> use printf
# -------------------------------
RUN set -eux; \
    if [ -x /usr/sbin/sshd ] && [ ! -x /usr/sbin/sshd.real ]; then \
      mv /usr/sbin/sshd /usr/sbin/sshd.real; \
      printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'' \
'if [[ " $* " == *" -D "* ]]; then' \
'  args=()' \
'  for a in "$@"; do' \
'    [[ "$a" == "-D" ]] && continue' \
'    args+=("$a")' \
'  done' \
'  /usr/sbin/sshd.real "${args[@]}" &' \
'  exit 0' \
'fi' \
'' \
'exec /usr/sbin/sshd.real "$@"' \
      > /usr/sbin/sshd; \
      chmod 755 /usr/sbin/sshd; \
    fi

# -------------------------------
# Expose ports (for local docker run; platform may ignore)
# -------------------------------
EXPOSE 22 8888

# -------------------------------
# Keep default CMD minimal.
# 平台会覆盖 CMD（你已经遇到），我们不依赖 CMD 来启动服务。
# -------------------------------
CMD ["/bin/bash", "-lc", "echo 'Image ready. Platform should run: sshd -D && /start.sh' && sleep infinity"]
