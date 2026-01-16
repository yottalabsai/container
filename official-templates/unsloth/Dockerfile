# =========================================================
# Base: Official Unsloth image
# =========================================================
FROM unsloth/unsloth AS base

# =========================================================
# logo stage (按你要求：COPY --from=logo yotta.txt /etc/yotta.txt)
# =========================================================
FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

# =========================================================
# scripts stage（start.sh 必须原样，不改内容）
# =========================================================
FROM scratch AS scripts
COPY container-template/start.sh start.sh

# =========================================================
# Final image
# =========================================================
FROM base

USER root

ENV JUPYTER_PASSWORD="unsloth"
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"

# -------------------------------
# Base tools + nginx + service
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
# service shim: make "service nginx start" always work
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

# -------------------------------
# Compatibility: start.sh expects python3.11
# Provide python3.11 alias to existing python3/python
# -------------------------------
RUN set -eux; \
    if command -v python3.11 >/dev/null 2>&1; then \
      echo "python3.11 exists"; \
    else \
      if command -v python3 >/dev/null 2>&1; then \
        target="$(command -v python3)"; \
      elif command -v python >/dev/null 2>&1; then \
        target="$(command -v python)"; \
      else \
        echo "No python found in base image" >&2; exit 1; \
      fi; \
      ln -sf "$target" /usr/local/bin/python3.11; \
    fi; \
    python3.11 -V

# -------------------------------
# Ensure pip + install CLI tools
# -------------------------------
RUN set -eux; \
    if command -v python3 >/dev/null 2>&1; then PY=python3; \
    elif command -v python >/dev/null 2>&1; then PY=python; \
    else echo "python not found" >&2; exit 1; fi; \
    "$PY" -m pip --version >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends python3-pip && rm -rf /var/lib/apt/lists/*); \
    "$PY" -m pip install --no-cache-dir -U pip; \
    "$PY" -m pip install --no-cache-dir "huggingface_hub[cli]" "datasets"

# -------------------------------
# Jupyter availability:
# - start.sh 可能直接调用 "jupyter"
# - 不假设 /opt/venv/bin/jupyter 一定存在
# - 找不到就用 pip 装 jupyterlab 并建立 /usr/local/bin/jupyter
# -------------------------------
RUN set -eux; \
    # pick python
    if command -v python3 >/dev/null 2>&1; then PY=python3; \
    elif command -v python >/dev/null 2>&1; then PY=python; \
    else echo "python not found" >&2; exit 1; fi; \
    # already in PATH?
    if command -v jupyter >/dev/null 2>&1; then \
      echo "jupyter already in PATH"; \
    else \
      # common locations
      if [ -x /opt/venv/bin/jupyter ]; then \
        ln -sf /opt/venv/bin/jupyter /usr/local/bin/jupyter; \
      elif [ -x /usr/local/bin/jupyter ]; then \
        :; \
      elif [ -x /usr/bin/jupyter ]; then \
        ln -sf /usr/bin/jupyter /usr/local/bin/jupyter; \
      else \
        # last resort: install jupyterlab
        "$PY" -m pip install --no-cache-dir "jupyterlab"; \
        # try to locate installed jupyter script
        JPATH="$("$PY" -c 'import shutil; p=shutil.which("jupyter"); print(p or "")')"; \
        if [ -n "$JPATH" ] && [ -x "$JPATH" ]; then \
          ln -sf "$JPATH" /usr/local/bin/jupyter; \
        fi; \
      fi; \
    fi; \
    # verify
    command -v jupyter >/dev/null 2>&1 || { echo "jupyter still not found" >&2; exit 1; }; \
    jupyter --version

# -------------------------------
# start.sh (必须原样)
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# -------------------------------
# branding (你要求必须原样)
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# Optional: create ubuntu user
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
# CRITICAL: platform injects "sshd -D && /start.sh"
# -D blocks forever -> /start.sh never runs
# Wrap sshd: if -D, daemonize then exit 0
# -------------------------------
RUN set -eux; \
    if [ -x /usr/sbin/sshd ] && [ ! -x /usr/sbin/sshd.real ]; then \
      mv /usr/sbin/sshd /usr/sbin/sshd.real; \
      printf '%s\n' \
'#!/usr/bin/env bash' \
'set -euo pipefail' \
'if [[ " $* " == *" -D "* ]]; then' \
'  args=()' \
'  for a in "$@"; do' \
'    [[ "$a" == "-D" ]] && continue' \
'    args+=("$a")' \
'  done' \
'  /usr/sbin/sshd.real "${args[@]}" &' \
'  exit 0' \
'fi' \
'exec /usr/sbin/sshd.real "$@"' \
      > /usr/sbin/sshd; \
      chmod 755 /usr/sbin/sshd; \
    fi

EXPOSE 22 8888 80

# 平台会覆盖 CMD；我们不依赖 CMD 启动
CMD ["/bin/bash", "-lc", "echo 'Image ready. Platform should run: sshd -D && /start.sh' && sleep infinity"]
