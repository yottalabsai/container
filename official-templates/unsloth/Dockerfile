# ==============================
# runtime: 工具 + Branding + 体验增强
# ==============================

FROM python-env AS runtime

ARG UBUNTU_USER

USER root
WORKDIR /home/${UBUNTU_USER}

# ----------------------------------------------------
# 额外工具：htop / nano / screenfetch / iputils / ping
# ----------------------------------------------------
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      htop \
      nano \
      iputils-ping \
      screenfetch \
      lsof \
      tree \
      jq \
      net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------
# start.sh：启动后进入用户环境 + 显示帮助
# ----------------------------------------------------
RUN cat >/start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth] welcome."

# 自动激活 venv
if [ -f "/opt/venv/bin/activate" ]; then
  source /opt/venv/bin/activate
fi

echo
echo "========================="
echo "  Unsloth Training Shell "
echo "========================="
echo
echo "Examples:"
echo "  python - <<'PY'"
echo "  from unsloth import is_good"
echo "  print(is_good())"
echo "  PY"
echo

bash
EOS

RUN chmod +x /start.sh

# ----------------------------------------------------
# post_start.sh：容器启动信息显示
# ----------------------------------------------------
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth] container started"

# welcome banner
if command -v screenfetch >/dev/null; then
    screenfetch
fi

echo "[INFO] Python: $(python --version)"
echo "[INFO] Torch:  $(python - <<'P'
import torch
print(torch.__version__)
P
)"
echo "[INFO] CUDA available: $(python - <<'P'
import torch
print(torch.cuda.is_available())
P
)"
EOS

RUN chmod +x /post_start.sh


# ----------------------------------------------------
# Branding: yotta 版权注入 + 文档导航
# ----------------------------------------------------
RUN echo "YottaLabs AI - Unsloth Platform" > /etc/yotta.txt

RUN echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs:  \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc

# ----------------------------------------------------
# /yotta 工具目录
# ----------------------------------------------------
RUN mkdir -p /yotta/tools && \
    echo "#!/usr/bin/env bash" > /yotta/tools/info.sh && \
    echo "echo '[Yotta] GPU:'; nvidia-smi || true" >> /yotta/tools/info.sh && \
    echo "echo '[Yotta] Python:'; python -V" >> /yotta/tools/info.sh && \
    chmod +x /yotta/tools/info.sh

ENV PATH="/yotta/tools:${PATH}"

# ----------------------------------------------------
# Shell 主题 & 欢迎彩色横幅
# ----------------------------------------------------
RUN echo '' >> /etc/bash.bashrc && \
    echo 'echo -e "\033[1;35mWelcome to Yotta Unsloth Training Environment!\033[0m"' >> /etc/bash.bashrc && \
    echo 'echo -e "Type: \033[1;36myotta-info\033[0m for usage."' >> /etc/bash.bashrc


# ----------------------------------------------------
# 登录体验
# ----------------------------------------------------
RUN ln -s /yotta/tools/info.sh /usr/local/bin/yotta-info


# 切回普通用户
USER ${UBUNTU_USER}
WORKDIR /home/${UBUNTU_USER}

CMD ["/start.sh"]
