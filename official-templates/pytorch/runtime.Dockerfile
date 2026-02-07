\
# syntax=docker/dockerfile:1.7
# ===== Runtime / Service Layer =====
# 说明：用户、SSH、nginx、branding、start.sh 等“运行期服务”集中在这里
# 约束：start.sh 不能改动（必须原样保留）

ARG BASE_IMAGE="base"
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# Env
# ===============================
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH \
    JUPYTER_PASSWORD=ubuntu

# ===============================
# Workspace
# ===============================
WORKDIR /
RUN mkdir -p /workspace && chmod 777 /workspace

# ===============================
# User
# ===============================
RUN useradd -ms /bin/bash ubuntu && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    echo "ubuntu:ubuntu" | chpasswd

# ===============================
# SSH config (start.sh 负责启动 sshd；这里确保配置允许密码登录)
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
COPY README.md /usr/share/nginx/html/README.md

COPY --from=logo yotta.txt /etc/yotta.txt
RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc

# ===============================
# Ports (不要写行尾注释，避免某些平台解析 containerPort 失败)
# ===============================
EXPOSE 22 80 8888

# ===============================
# Entrypoint: root 直接跑 start.sh（不改你的公共 start.sh）
# ===============================
USER root
WORKDIR /root
CMD ["/bin/bash", "-lc", "exec /start.sh"]
