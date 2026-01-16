FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    JUPYTER_PORT=8888 \
    JUPYTER_PASSWORD=unsloth \
    USER_PASSWORD=unsloth \
    VENV_PATH=/opt/venv

# ---- system deps ----
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      sudo openssh-server nginx \
      tini \
      build-essential \
      software-properties-common; \
    add-apt-repository -y ppa:deadsnakes/ppa; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev; \
    rm -rf /var/lib/apt/lists/*

# ---- python venv ----
RUN set -eux; \
    python3.11 -m venv "${VENV_PATH}"; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir -U pip setuptools wheel; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir \
      jupyterlab jupyter_server ipykernel; \
    "${VENV_PATH}/bin/pip" install --no-cache-dir \
      numpy pandas matplotlib

# Make venv visible for root (note: sudo -u may lose PATH; entry.sh uses absolute jupyter path)
ENV PATH="${VENV_PATH}/bin:${PATH}"

# ---- user: unsloth ----
RUN set -eux; \
    groupadd -g 1000 unsloth || true; \
    useradd -m -u 1000 -g 1000 -s /bin/bash unsloth || true; \
    echo "unsloth ALL=(ALL) ALL" > /etc/sudoers.d/unsloth; \
    chmod 0440 /etc/sudoers.d/unsloth; \
    mkdir -p /home/unsloth/.ssh /workspace/work /workspace/unsloth-notebooks; \
    chmod 700 /home/unsloth/.ssh; \
    chown -R unsloth:unsloth /home/unsloth /workspace

# ---- branding ----
COPY --from=logo /yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ---- sshd ----
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config; \
    echo "AllowUsers unsloth" >> /etc/ssh/sshd_config

# ---- nginx (optional) ----
RUN set -eux; \
    rm -f /etc/nginx/sites-enabled/default || true; \
    cat >/etc/nginx/sites-available/default <<'NGINX'
server {
    listen 80 default_server;
    server_name _;
    location / {
        return 200 "ok\n";
    }
}
NGINX
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# ---- unsloth notebooks (best-effort) ----
RUN set -eux; \
    git clone --depth 1 https://github.com/unslothai/notebooks /workspace/unsloth-notebooks || true; \
    chown -R unsloth:unsloth /workspace/unsloth-notebooks || true

# ---- entrypoint ----
RUN set -eux; \
    cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 1) SSH key injection (env: SSH_KEY)
if [[ -n "${SSH_KEY:-}" ]]; then
  install -d -m 700 -o unsloth -g unsloth /home/unsloth/.ssh
  echo "${SSH_KEY}" > /home/unsloth/.ssh/authorized_keys
  chown unsloth:unsloth /home/unsloth/.ssh/authorized_keys
  chmod 600 /home/unsloth/.ssh/authorized_keys
fi

# 2) Set sudo password (env: USER_PASSWORD)
echo "unsloth:${USER_PASSWORD:-unsloth}" | chpasswd

# 3) Start services
/usr/sbin/sshd
nginx || true

# 4) Jupyter password hash from plaintext JUPYTER_PASSWORD
JUPYTER_PW="${JUPYTER_PASSWORD:-unsloth}"
HASH="$(python3.11 - <<PY
from jupyter_server.auth import passwd
print(passwd("${JUPYTER_PW}"))
PY
)"

# 5) Launch Jupyter Lab as non-root.
# IMPORTANT: use absolute path so sudo/PATH won't break ("jupyter: command not found")
exec sudo -u unsloth -H bash -lc \
  "/opt/venv/bin/jupyter lab \
    --ip=0.0.0.0 \
    --port=${JUPYTER_PORT:-8888} \
    --no-browser \
    --ServerApp.token='' \
    --ServerApp.password='${HASH}' \
    --ServerApp.allow_origin='*' \
    --ServerApp.root_dir=/workspace"
EOF
RUN chmod +x /entry.sh

EXPOSE 8888 22 80

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entry.sh"]
