# =========================================
# Multi-arch selector (amd64 / arm64)
# =========================================
# 说明：
# - 这里默认使用 NVIDIA NGC 的 PyTorch 基像（带 CUDA / cuDNN）
# - 某些 NGC 镜像可能没有 arm64 版本；若 arm64 拉取失败，请替换为你可用的 arm64 基像
ARG BASE_IMAGE_AMD64="nvcr.io/nvidia/pytorch:24.10-py3"
ARG BASE_IMAGE_ARM64="nvcr.io/nvidia/pytorch:24.10-py3"

FROM ${BASE_IMAGE_AMD64} AS base_amd64
FROM ${BASE_IMAGE_ARM64} AS base_arm64

ARG TARGETARCH
FROM base_${TARGETARCH} AS base

# =========================================
# System packages & Python deps
# =========================================
ENV DEBIAN_FRONTEND=noninteractive

# 安装 sudo/bash/curl/tini 等基础工具；不改动 NVIDIA ENTRYPOINT
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      sudo bash curl ca-certificates tini \
      # 如确有需要可安装：openssh-server
    && rm -rf /var/lib/apt/lists/*

# 可选：升级 pip（按需）
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# 安装 vLLM 及常见依赖（版本按需锁定；此处给出兼容性较强的写法）
# - 若你的上游“Verl”基像已预装 vLLM，可注释掉本段
RUN python -m pip install --no-cache-dir \
      vllm \
      transformers \
      accelerate \
      sentencepiece \
      safetensors

# =========================================
# Runtime ENV（运行时可覆盖）
# =========================================
# 模型与服务参数：可在 K8s/Compose 中用 env 覆盖
ENV VLLM_HOST=0.0.0.0 \
    VLLM_PORT=8000 \
    MODEL_NAME=Wan2.2 \
    TP_SIZE=1 \
    MAX_MODEL_LEN=32768 \
    GPU_MEM_UTIL=0.90 \
    VLLM_EXTRA=""

# 可选：HF 缓存/镜像站等（按需）
# ENV HF_HOME=/opt/hf-cache \
#     VLLM_DOWNLOAD_DIR=/opt/models

# =========================================
# /start.sh —— 统一启动入口（最终 exec 业务进程为 PID 1）
# =========================================
# 特性：
# - 支持通过环境变量 SSH_PUBLIC_KEY 在启动时写入 /root/.ssh/authorized_keys（默认不写）
# - 最后以 exec 方式启动 vLLM OpenAI API Server，确保信号与退出码正确
RUN set -eux; \
  cat >/start.sh <<'EOS' && chmod +x /start.sh
#!/usr/bin/env bash
set -euo pipefail

# -------- (可选) 注入 SSH 公钥：设置环境变量 SSH_PUBLIC_KEY 即可写入 ----------
if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
  echo "[start.sh] Injecting SSH public key..."
  install -d -m 700 -o root -g root /root/.ssh
  # 直接用 root 写入，无需 sudo；若你坚持 sudo，这个镜像已安装
  echo "${SSH_PUBLIC_KEY}" >> /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# -------- (可选) 如果你真的要启用 sshd（不推荐业务容器开启），取消注释 ----------
# if command -v /usr/sbin/sshd >/dev/null 2>&1; then
#   mkdir -p /var/run/sshd
#   /usr/sbin/sshd || true
# fi

echo "[start.sh] Launching vLLM OpenAI API..."
echo "[start.sh] MODEL_NAME=${MODEL_NAME}"
echo "[start.sh] HOST=${VLLM_HOST} PORT=${VLLM_PORT} TP_SIZE=${TP_SIZE} MAX_MODEL_LEN=${MAX_MODEL_LEN} GPU_MEM_UTIL=${GPU_MEM_UTIL}"
echo "[start.sh] EXTRA=${VLLM_EXTRA}"

# 如需自定义下载目录、并发/批处理参数，可通过 VLLM_EXTRA 传入：
# 例如：VLLM_EXTRA="--download-dir /opt/models --max-num-batched-tokens 8192 --dtype auto"
exec python -m vllm.entrypoints.openai.api_server \
  --host "${VLLM_HOST}" \
  --port "${VLLM_PORT}" \
  --model "${MODEL_NAME}" \
  --tensor-parallel-size "${TP_SIZE}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --gpu-memory-utilization "${GPU_MEM_UTIL}" \
  ${VLLM_EXTRA}
EOS

# =========================================
# Ports / Healthcheck（按需）
# =========================================
EXPOSE ${VLLM_PORT}
# 如确有 sshd 需求才开放 22（默认不建议）
# EXPOSE 22

# 可选：如果你的镜像/服务实现了健康端点，可启用健康检查
# HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
#   CMD curl -fsS "http://127.0.0.1:${VLLM_PORT}/health" || exit 1

# =========================================
# Final CMD
# =========================================
# 保留 NVIDIA 的 ENTRYPOINT（/opt/nvidia/nvidia_entrypoint.sh），仅提供非空 CMD。
# 这样即使 K8s 不传 command/args，也能稳定启动，不会出现 "exec: : not found"
CMD ["bash","-lc","/start.sh"]
