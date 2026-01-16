ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1

WORKDIR /workspace

# =========================================================
# System packages (APT hardened)
# =========================================================
USER root
RUN set -eux; \
    mkdir -p /tmp/apt-lists/partial; \
    chmod -R 755 /tmp/apt-lists; \
    apt-get -o Dir::State::lists=/tmp/apt-lists update -y; \
    apt-get -o Dir::State::lists=/tmp/apt-lists install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates curl wget git git-lfs locales tzdata \
      build-essential pkg-config ninja-build \
      ffmpeg libgl1 libglib2.0-0 \
      vim jq tree htop tmux rsync \
      zip unzip less procps net-tools lsof sudo \
      iproute2 iputils-ping dnsutils \
      nginx openssh-server openssh-client \
      software-properties-common \
      libnccl2 libnccl-dev \
      tini; \
    git lfs install; \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime; \
    echo "Etc/UTC" > /etc/timezone; \
    dpkg-reconfigure -f noninteractive tzdata; \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; \
    locale-gen; \
    update-locale; \
    rm -rf /tmp/apt-lists

# =========================================================
# Python 3.11 (NO get-pip.py)
# =========================================================
RUN set -eux; \
    mkdir -p /tmp/apt-lists/partial; \
    chmod -R 755 /tmp/apt-lists; \
    add-apt-repository ppa:deadsnakes/ppa -y; \
    apt-get -o Dir::State::lists=/tmp/apt-lists update -y; \
    apt-get -o Dir::State::lists=/tmp/apt-lists install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-distutils python3-pip; \
    rm -rf /tmp/apt-lists; \
    python3.11 -m pip install --no-cache-dir -U pip wheel setuptools \
      --retries 10 --timeout 60

# =========================================================
# Python tools (pip hardened)
# =========================================================
RUN set -eux; \
    python3.11 -m pip install --no-cache-dir \
      "huggingface_hub[cli]" \
      "datasets" \
      "jupyterlab" \
      "unsloth" \
      --retries 10 --timeout 60

# =========================================================
# nccl-tests
# =========================================================
RUN set -eux; \
    git clone --depth 1 https://github.com/NVIDIA/nccl-tests.git /tmp/nccl-tests; \
    make -C /tmp/nccl-tests -j"$(nproc)"; \
    mkdir -p /usr/local/bin/nccl-tests; \
    cp -a /tmp/nccl-tests/build/* /usr/local/bin/nccl-tests/; \
    rm -rf /tmp/nccl-tests

# =========================================================
# SSH hardening
# =========================================================
RUN set -eux; \
    mkdir -p /var/run/sshd; \
    sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config; \
    sed -ri 's/^#?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# =========================================================
# Ubuntu user (方案 A)
# =========================================================
RUN set -eux; \
    if ! id ubuntu >/dev/null 2>&1; then \
      groupadd -g 1000 ubuntu || true; \
      useradd -m -u 1000 -g 1000 -s /bin/bash ubuntu; \
    fi; \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu; \
    chmod 0440 /etc/sudoers.d/ubuntu; \
    mkdir -p /home/ubuntu/.ssh /workspace; \
    chmod 700 /home/ubuntu/.ssh; \
    chown -R ubuntu:ubuntu /home/ubuntu /workspace

# =========================================================
# Nginx proxy & static files
# =========================================================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

# =========================================================
# Branding
# =========================================================
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# =========================================================
# Platform start.sh (unchanged)
# =========================================================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# =========================================================
# Entrypoint: ssh + jupyter
# =========================================================
ENV JUPYTER_PORT=7861

RUN cat >/entry.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# SSH key for ubuntu
if [[ -n "${PUBLIC_KEY:-}" ]]; then
  install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
  echo "${PUBLIC_KEY}" > /home/ubuntu/.ssh/authorized_keys
  chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
fi

# Run platform script (do not depend on it)
/start.sh || true &

# Ensure sshd
/usr/sbin/sshd

# Jupyter token logic (compat JUPYTER_PASSWORD)
TOKEN="${JUPYTER_TOKEN:-${JUPYTER_PASSWORD:-}}"
if [[ -z "${TOKEN}" ]]; then
  TOKEN="$(python3.11 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"
  echo "[start] JUPYTER_TOKEN(auto)=${TOKEN}"
fi

exec sudo -u ubuntu -H bash -lc \
  "python3.11 -m jupyter lab \
    --ip=0.0.0.0 \
    --port=${JUPYTER_PORT:-7861} \
    --no-browser \
    --ServerApp.token='${TOKEN}' \
    --ServerApp.password='' \
    --ServerApp.allow_origin='*'"
EOF

RUN chmod 755 /entry.sh

EXPOSE 22 7861

ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["/entry.sh"]
