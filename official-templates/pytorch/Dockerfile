ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG TORCH
ARG PYTHON_VERSION

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash
# important: set nvidia environment variables, not here, change in start.sh
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda-12.8/bin:$PATH
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH

WORKDIR /

RUN mkdir /workspace

RUN apt-get update --yes --allow-unauthenticated && \
    apt-get upgrade --yes && \
    apt install --yes --no-install-recommends \
    git acl wget curl bash libgl1 software-properties-common \
    openssh-server nginx sudo && \
    if [ -n "${PYTHON_VERSION}" ]; then \
        add-apt-repository ppa:deadsnakes/ppa && \
        apt install "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" -y --no-install-recommends; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Set up Python and pip
RUN if [ -n "${PYTHON_VERSION}" ]; then \
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    rm /usr/bin/python3 && \
    ln -s /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python get-pip.py; \
    fi

RUN pip install --upgrade --no-cache-dir pip
RUN if [ -n "${TORCH}" ]; then pip install --upgrade --no-cache-dir ${TORCH}; fi 
RUN pip install --upgrade --no-cache-dir jupyterlab ipywidgets jupyter-archive notebook==7.3.3

#Create ubuntu user with sudo privileges
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu

# Setup SSH
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && \
    chown -R root:root /root/.ssh && \
    setfacl -R -m u:ubuntu:rwx /root/.ssh

# Link CUDA bin
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/

# Remove existing SSH host keys
RUN rm -f /etc/ssh/ssh_host_*

# Copy NGINX config
COPY --from=proxy nginx.conf /etc/nginx/nginx.conf
COPY --from=proxy readme.html /usr/share/nginx/html/readme.html

COPY README.md /usr/share/nginx/html/README.md

# Start script
COPY --from=scripts start.sh /
RUN chmod +x /start.sh

# Welcome Message
COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc
RUN echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://www.yottalabs.ai/\033[0m and \033[1;34mhttps://www.yottalabs.ai/\033[0m\n\n"' >> /root/.bashrc

# Expose Jupyter port
EXPOSE 8888

# Switch to ubuntu user
USER ubuntu
WORKDIR /home/ubuntu

CMD [ "sudo","/start.sh" ]
