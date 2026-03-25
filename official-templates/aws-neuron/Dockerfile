ARG BASE_IMAGE="ubuntu:22.04"
FROM ${BASE_IMAGE}

# ===============================
# Build args
# ===============================
ARG TORCH_NEURONX_VERSION="2.*"
ARG NEURONX_CC_VERSION="2.*"
ARG MINI_SGLANG_NEURON_COMMIT="e984a5b7aaf539698b94e7f9fdadb1e40b8ff155"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/opt/aws/neuron/bin:/usr/local/bin:/usr/bin:/bin:$PATH \
    NEURON_RT_NUM_CORES=1 \
    HF_HOME=/workspace/hf \
    JUPYTER_PASSWORD=ubuntu

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===============================
# Base system packages
# ===============================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      git wget curl ca-certificates bash \
      gnupg2 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && mkdir -p /var/run/sshd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# Python 3.11 via deadsnakes PPA
# (start.sh requires python3.11)
# ===============================
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      python3.11 python3.11-venv python3.11-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    python3.11 -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN ln -sf /usr/bin/python3.11 /usr/local/bin/python3 && \
    ln -sf /usr/bin/python3.11 /usr/local/bin/python

# ===============================
# AWS Neuron APT repo + runtime
# (runtime-lib + collectives cover inf2 and trn1/trn2; dkms is host-side only)
# ===============================
RUN wget -qO- https://apt.repos.neuron.amazonaws.com/GPG-PUB-KEY-AMAZON-AWS-NEURON.PUB \
      | gpg --dearmor -o /etc/apt/trusted.gpg.d/neuron.gpg && \
    echo "deb https://apt.repos.neuron.amazonaws.com jammy main" \
      > /etc/apt/sources.list.d/neuron.list && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      aws-neuronx-tools \
      aws-neuronx-runtime-lib \
      aws-neuronx-collectives \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# torch-neuronx (inf2 + trn1/trn2)
# ===============================
RUN python3.11 -m pip install --no-cache-dir \
      "torch-neuronx==${TORCH_NEURONX_VERSION}" torchvision torchaudio \
      --extra-index-url https://pip.repos.neuron.amazonaws.com

# ===============================
# Neuron compiler + distributed training + inference optimisation
# ===============================
RUN python3.11 -m pip install --no-cache-dir \
      "neuronx-cc==${NEURONX_CC_VERSION}" \
      transformers-neuronx \
      neuronx-distributed \
      --extra-index-url https://pip.repos.neuron.amazonaws.com

# ===============================
# Hugging Face stack + JupyterLab
# ===============================
RUN python3.11 -m pip install --no-cache-dir \
      "transformers>=4.56.0,<4.57.3" datasets huggingface_hub accelerate \
      jupyterlab ipywidgets jupyter-archive "notebook==7.3.3"

# ===============================
# mini-sglang-neuron (Yotta LLM inference for Trainium/Inferentia)
# ===============================
RUN python3.11 -m pip install --no-cache-dir ninja && \
    git clone https://github.com/yottalabsai/mini-sglang-neuron.git \
      /opt/mini-sglang-neuron && \
    git -C /opt/mini-sglang-neuron checkout "${MINI_SGLANG_NEURON_COMMIT}" && \
    python3.11 -m pip install --no-cache-dir \
      --extra-index-url https://pip.repos.neuron.amazonaws.com \
      /opt/mini-sglang-neuron && \
    chmod +x /opt/mini-sglang-neuron/server.sh /opt/mini-sglang-neuron/run_minisgl.sh

# Build-time assertion: prevents pushing a broken image
RUN python3.11 -c "import jupyter; import jupyterlab; print('python3.11 jupyter ok')"
RUN python3.11 -c "import minisgl; print('minisgl ok')"

# ===============================
# User
# ===============================
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

# ===============================
# SSH config (start.sh handles sshd startup)
# ===============================
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    rm -f /etc/ssh/ssh_host_*

# ===============================
# start.sh (from buildx bake context "scripts")
# ===============================
COPY --from=scripts start.sh /start.sh
RUN chmod 755 /start.sh

# ===============================
# nginx / branding
# ===============================
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Ports
# ===============================
EXPOSE 22 80 8888

USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]
