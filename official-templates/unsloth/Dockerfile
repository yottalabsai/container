# ==============================
# Unsloth LLM Fine-tuning 镜像（Yotta 扩展版）
# 底座：官方 unsloth/unsloth
# ==============================
ARG BASE_IMAGE="unsloth/unsloth:latest"

FROM ${BASE_IMAGE} AS base

SHELL ["/bin/bash","-o","pipefail","-c"]

# 这里不再动 PyTorch / Unsloth 本体，只叠加工具 + branding

# ==============================
# runtime: 小工具 + Branding + 启动体验
# ==============================
FROM base AS runtime

USER root
WORKDIR /workspace

# 实用小工具
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      htop \
      nano \
      iputils-ping \
      lsof \
      tree \
      jq \
      net-tools && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# /yotta 工具目录 + 简单系统信息脚本
RUN mkdir -p /yotta/tools && \
    echo "#!/usr/bin/env bash" > /yotta/tools/info.sh && \
    echo "echo '[Yotta] GPU:'; nvidia-smi || true" >> /yotta/tools/info.sh && \
    echo "echo '[Yotta] Python:'; python -V" >> /yotta/tools/info.sh && \
    echo "echo '[Yotta] Unsloth import test:'" >> /yotta/tools/info.sh && \
    echo "python - << 'PY'" >> /yotta/tools/info.sh && \
    echo "import unsloth" >> /yotta/tools/info.sh && \
    echo "print('  module:', unsloth)" >> /yotta/tools/info.sh && \
    echo "print('  version:', getattr(unsloth, '__version__', 'unknown'))" >> /yotta/tools/info.sh && \
    echo "PY" >> /yotta/tools/info.sh && \
    chmod +x /yotta/tools/info.sh && \
    ln -s /yotta/tools/info.sh /usr/local/bin/yotta-info

ENV PATH="/yotta/tools:${PATH}"

# Branding 文案
RUN echo "YottaLabs AI - Unsloth Training Platform" > /etc/yotta.txt

# 交互 shell：不改官方 CMD，只作为可选入口
RUN cat >/start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth x Yotta] interactive shell."

# 官方镜像里一般有 venv，能用就用，不能用就算了
if [ -f "/opt/venv/bin/activate" ]; then
  source /opt/venv/bin/activate || true
fi

echo
echo "==============================="
echo "  Unsloth Training Shell (Yotta)"
echo "==============================="
echo
echo "Try:"
echo "  yotta-info"
echo
echo "  python - << 'PY'"
echo "  from unsloth import FastLanguageModel"
echo '  model, tokenizer = FastLanguageModel.from_pretrained('
echo '      model_name=\"unsloth/Meta-Llama-3.1-8B-Instruct-bnb-4bit\",'
echo '      max_seq_length=2048,'
echo '      dtype=None,'
echo '      load_in_4bit=True,'
echo '  )'
echo "  PY"
echo

bash
EOS

# 预留给编排器用的 post_start.sh（如果以后想在外面调用）
RUN cat >/post_start.sh <<'EOS'
#!/usr/bin/env bash
set -e

echo "[Unsloth x Yotta] container started."

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

# 商业化元素：登录提示 + docs
RUN chmod +x /post_start.sh /start.sh && \
    echo 'cat /etc/yotta.txt' >> /root/.bashrc && \
    echo 'echo -e "\nFor docs: \033[1;34mhttps://www.yottalabs.ai/\033[0m\n"' >> /root/.bashrc && \
    echo '' >> /etc/bash.bashrc && \
    echo 'echo -e "\033[1;35mWelcome to Yotta Unsloth Training Environment!\033[0m"' >> /etc/bash.bashrc && \
    echo 'echo -e "Type: \033[1;36myotta-info\033[0m for quick system info."' >> /etc/bash.bashrc

# 注意：不 override 官方 ENTRYPOINT / CMD
# 直接 docker run 仍然使用 unsloth/unsloth 的默认行为（Jupyter / SSH 等）
# 需要用我们自带 shell 时，可运行：
#   docker run --entrypoint /start.sh ...
