# =========================================================
# Base: Official Unsloth image
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

# 你要求：JUPYTER_PASSWORD 通过环境变量存在（值可被平台覆盖）
ENV JUPYTER_PASSWORD="unsloth"

# -------------------------------
# Tools + nginx + service support
# 关键：让 start.sh 里如果用 service nginx start 不会炸
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      sudo openssh-server \
      tini \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      nginx sysvinit-utils; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# service shim (兜底)
# 有些镜像即使装了 sysvinit-utils，也可能没有 nginx init script
# 这个 shim 只保证 "service nginx start/stop/restart/status" 可用
# -------------------------------
RUN set -eux; \
    printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'svc="${1:-}"; cmd="${2:-}"' \
'if [[ "$svc" == "nginx" ]]; then' \
'  case "$cmd" in' \
'    start)   nginx ;;' \
'    stop)    nginx -s quit || true ;;' \
'    restart) nginx -s reload || (nginx -s quit || true; nginx) ;;' \
'    status)  pgrep -x nginx >/dev/null && echo "nginx is running" || (echo "nginx is not running"; exit 3) ;;' \
'    *) echo "usage: service nginx {start|stop|restart|status}" >&2; exit 2 ;;' \
'  esac' \
'  exit 0' \
'fi' \
'exec /usr/sbin/service "$@"' \
      > /usr/local/sbin/service; \
    chmod 755 /usr/local/sbin/service

# 确保 PATH 里优先用我们这个 service（不破坏系统自带的）
ENV PATH="/usr/local/sbin:${PATH}"

# -------------------------------
# Python CLIs (huggingface-cli, datasets-cli)
# 官方镜像不保证 /opt/venv，所以动态选 python
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
# Optional: create ubuntu user (你之前问过“我不是有 ubuntu 吗”)
# 不会影响官方 unsloth 用户；只是补一个 ubuntu 以兼容平台/习惯
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

EXPOSE 22 8888 80

# 平台会覆盖 CMD；我们不依赖 CMD 启动服务
CMD ["/bin/bash", "-lc", "echo 'Image ready. Platform should run: sshd -D && /start.sh' && sleep infinity"]
