ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG TORCH=""
ARG PYTHON_VERSION="3.11"

# ===== ADD: nccl-tests version (optional) =====
ARG NCCL_TESTS_VERSION="v2.13.11"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda-12.8/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH

WORKDIR /

# 基础目录
RUN mkdir -p /workspace && chmod 777 /workspace

# 系统依赖 + SSH + Nginx + 工具
# ===== ADD: jq tree rsync netcat-openbsd + build-essential/pkg-config + OpenMPI (for nccl-tests) =====
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git acl wget curl bash libgl1 software-properties-common \
      locales tzdata \
      openssh-server nginx sudo \
      tmux vim zsh zip unzip less procps net-tools htop \
      jq tree rsync netcat-openbsd \
      build-essential pkg-config \
      openmpi-bin libopenmpi-dev libmpi-dev \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && \
    mkdir -p /var/run/sshd && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 安装指定 Python 版本（如果传了 PYTHON_VERSION）
RUN if [ -n "${PYTHON_VERSION}" ]; then \
      add-apt-repository ppa:deadsnakes/ppa -y && \
      apt-get update -y && \
      apt-get install -y --no-install-recommends \
        "python${PYTHON_VERSION}" \
        "python${PYTHON_VERSION}-dev" \
        "python${PYTHON_VERSION}-venv" && \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
      ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
      curl -fsSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
      python get-pip.py && rm -f get-pip.py ; \
    else \
      echo "PYTHON_VERSION not set, using system python3" && \
      python3 -m ensurepip --upgrade || true ; \
    fi

# 升级 pip
RUN python -m pip install --upgrade --no-cache-dir pip

# 安装 torch（由 TORCH 参数完全控制，例如：TORCH='torch==2.4.0 torchvision==2.4.0 --index-url ...'）
RUN if [ -n "${TORCH}" ]; then \
      echo "Installing TORCH packages: ${TORCH}" && \
      python -m pip install --upgrade --no-cache-dir ${TORCH} ; \
    fi

# 安装 Jupyter 相关
RUN python -m pip install --upgrade --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3

# ===== ADD: Hugging Face CLI + datasets-cli =====
# huggingface-cli / hf 来自 huggingface_hub；datasets-cli 来自 datasets
RUN python -m pip install --upgrade --no-cache-dir \
      "huggingface_hub[cli]" \
      datasets

# ===== NCCL tests (no MPI, safest) =====
RUN set -eux; \
    git clone --branch "${NCCL_TESTS_VERSION}" --depth 1 \
      https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests; \
    make -C /opt/nccl-tests -j"$(nproc)" MPI=0; \
    ln -sf /opt/nccl-tests/build/* /usr/local/bin/; \
    rm -rf /opt/nccl-tests/.git


# 创建 ubuntu 用户 + sudo 权限
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

# SSH 配置（root + ubuntu 都可用）
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh || true && \
    sed -i "s/#PasswordAuthentication yes/PasswordAuthentication yes/" /etc/ssh/sshd_config || true && \
    sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config || true && \
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/" /etc/ssh/sshd_config || true

# 可选：删除现有 SSH host key（通常配合 start.sh 里的 ssh-keygen -A）
RUN rm -f /etc/ssh/ssh_host_* || true

# 链接 CUDA bin（方便直接用 nvcc / nvidia-smi 等）
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/ || true

# Nginx / README / logo（依赖 buildx context: proxy / logo）
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m\n\n"' >> /root/.bashrc

# 暴露端口
# SSH
EXPOSE 22
# Nginx
EXPOSE 80
# Jupyter
EXPOSE 8888

# 切到 ubuntu 用户
USER ubuntu
WORKDIR /home/ubuntu

# 入口：交给 start.sh（通常里面会起 sshd + nginx + jupyter）
CMD ["sudo", "/start.sh"]
