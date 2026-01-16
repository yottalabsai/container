# =========================================================
# Base: Official Unsloth image (includes /workspace/unsloth-notebooks)
# =========================================================
FROM unsloth/unsloth AS base

# =========================================================
# logo stage (你要的写法：COPY --from=logo yotta.txt /etc/yotta.txt)
# =========================================================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

# =========================================================
# scripts stage（保持 start.sh 原样，不改内容）
# =========================================================
FROM scratch AS scripts
COPY container-template/start.sh start.sh

# =========================================================
# Final image
# =========================================================
FROM base

USER root

# 你只要求 JUPYTER_PASSWORD 确保存在（值可被平台/运行时覆盖）
ENV JUPYTER_PASSWORD="unsloth"

# -------------------------------
# System tools you asked for
# vim, jq, tree, htop, tmux, rsync, etc.
# -------------------------------
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
# 官方镜像不保证 /opt/venv，因此用 python3/pip3 兜底安装
# -------------------------------
RUN set -eux; \
    if command -v python3 >/dev/null 2>&1; then PY=python3; \
    elif command -v python >/dev/null 2>&1; then PY=python; \
    else echo "python not found" >&2; exit 1; fi; \
    "$PY" -m pip --version || (apt-get update && apt-get install -y --no-install-recommends python3-pip && rm -rf /var/lib/apt/lists/*); \
    "$PY" -m pip install --no-cache-dir -U pip; \
    "$PY" -m pip install --no-cache-dir "huggingface_hub[cli]" "datasets"

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

EXPOSE 22 8888

CMD ["/bin/bash", "-lc", "echo 'Image ready. Platform should run: sshd -D && /start.sh' && sleep infinity"]
