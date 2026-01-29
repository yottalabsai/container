FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /workspace

# -------------------------------
# base system tools
# -------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --allow-change-held-packages \
      ca-certificates \
      curl \
      wget \
      git \
      sudo \
      openssh-server \
      nginx \
      tini \
      build-essential \
      make \
      g++ \
      software-properties-common \
      vim \
      jq \
      tree \
      htop \
      tmux \
      rsync \
      pciutils \
      iproute2 \
      net-tools \
      lsof \
      procps; \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# python
# -------------------------------
RUN ln -s /usr/bin/python3 /usr/bin/python || true
RUN python -m pip install --no-cache-dir \
    torch \
    transformers \
    accelerate \
    verl

# -------------------------------
# sshd dirs
# -------------------------------
RUN mkdir -p /var/run/sshd

# -------------------------------
# Branding
# -------------------------------
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# -------------------------------
# start.sh (must not change)
# -------------------------------
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# =================================================
# Verl template files (NO model weights, NO entrypoint)
# =================================================
COPY official-templates/verl/Verl_Qwen2.5_Demo.ipynb /workspace/Verl_Qwen2.5_Demo.ipynb

# -------------------------------------------------
# No CMD / No ENTRYPOINT
# Lifecycle is fully managed by platform:
# sudo -E /start.sh
# -------------------------------------------------
