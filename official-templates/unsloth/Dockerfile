FROM unsloth/unsloth AS base

FROM base

USER root

ENV JUPYTER_PASSWORD="unsloth"
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"

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

RUN set -eux; \
    if command -v python3.11 >/dev/null 2>&1; then \
      :; \
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

RUN set -eux; \
    if command -v python3 >/dev/null 2>&1; then PY=python3; \
    elif command -v python >/dev/null 2>&1; then PY=python; \
    else echo "python not found" >&2; exit 1; fi; \
    "$PY" -m pip --version >/dev/null 2>&1 || (apt-get update && apt-get install -y --no-install-recommends python3-pip && rm -rf /var/lib/apt/lists/*); \
    "$PY" -m pip install --no-cache-dir -U pip; \
    "$PY" -m pip install --no-cache-dir "huggingface_hub[cli]" "datasets"

RUN set -eux; \
    if command -v python3 >/dev/null 2>&1; then PY=python3; \
    elif command -v python >/dev/null 2>&1; then PY=python; \
    else echo "python not found" >&2; exit 1; fi; \
    if command -v jupyter >/dev/null 2>&1; then \
      :; \
    else \
      if [ -x /opt/venv/bin/jupyter ]; then \
        ln -sf /opt/venv/bin/jupyter /usr/local/bin/jupyter; \
      elif [ -x /usr/bin/jupyter ]; then \
        ln -sf /usr/bin/jupyter /usr/local/bin/jupyter; \
      else \
        "$PY" -m pip install --no-cache-dir "jupyterlab"; \
        JPATH="$("$PY" -c 'import shutil; p=shutil.which("jupyter"); print(p or "")')"; \
        [ -n "$JPATH" ] && [ -x "$JPATH" ] && ln -sf "$JPATH" /usr/local/bin/jupyter; \
      fi; \
    fi; \
    command -v jupyter >/dev/null 2>&1; \
    jupyter --version

COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

RUN set -eux; \
    if ! id ubuntu >/dev/null 2>&1; then \
      useradd -m -s /bin/bash ubuntu; \
      usermod -aG sudo ubuntu; \
      echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu; \
      chmod 0440 /etc/sudoers.d/90-ubuntu; \
    fi; \
    mkdir -p /workspace/work; \
    chown -R ubuntu:ubuntu /workspace || true

RUN set -eux; \
    mkdir -p /run/sshd; \
    ssh-keygen -A; \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN set -eux; \
    cat > /entrypoint.sh <<'EOF' \
#!/usr/bin/env bash
set -euo pipefail

mkdir -p /run/sshd
ssh-keygen -A >/dev/null 2>&1 || true

if command -v /usr/sbin/sshd >/dev/null 2>&1; then
  /usr/sbin/sshd || true
elif command -v sshd >/dev/null 2>&1; then
  sshd || true
fi

if [ -x /start.sh ]; then
  exec /start.sh
fi

exec bash -lc "sleep infinity"
EOF
    chmod 755 /entrypoint.sh

EXPOSE 22 8888 80

ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
CMD []
