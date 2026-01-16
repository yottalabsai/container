FROM unsloth/unsloth AS base

FROM scratch AS logo
COPY container-template/yotta.txt yotta.txt

FROM scratch AS scripts
COPY container-template/start.sh start.sh

FROM base

USER root

ENV JUPYTER_PASSWORD="unsloth"
ENV PATH="/usr/local/sbin:/usr/local/bin:${PATH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git sudo \
      openssh-server tini \
      vim jq tree htop tmux rsync \
      pciutils iproute2 net-tools lsof procps \
      nginx sysvinit-utils && \
    rm -rf /var/lib/apt/lists/*

RUN printf '%s\n' \
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
> /usr/local/sbin/service && \
chmod 755 /usr/local/sbin/service

RUN if command -v python3.11 >/dev/null 2>&1; then :; \
    else \
      if command -v python3 >/dev/null 2>&1; then ln -sf "$(command -v python3)" /usr/local/bin/python3.11; \
      elif command -v python >/dev/null 2>&1; then ln -sf "$(command -v python)" /usr/local/bin/python3.11; \
      else echo "no python found" && exit 1; fi; \
    fi && \
    python3.11 -V

RUN python3.11 -m pip install --no-cache-dir -U pip && \
    python3.11 -m pip install --no-cache-dir \
      jupyterlab \
      huggingface_hub[cli] \
      datasets

COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

RUN id ubuntu 2>/dev/null || useradd -m -s /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-ubuntu && \
    chmod 0440 /etc/sudoers.d/90-ubuntu && \
    mkdir -p /workspace/work && \
    chown -R ubuntu:ubuntu /workspace

RUN mkdir -p /run/sshd && \
    ssh-keygen -A && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN cat > /entrypoint.sh <<'EOF' && \
chmod 755 /entrypoint.sh
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

EXPOSE 22 8888 80

ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
CMD []
