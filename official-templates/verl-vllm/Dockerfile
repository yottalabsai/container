# ===== Base & Args =====
ARG BASE_IMAGE="nvidia/cuda:12.6.2-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

ARG PYTHON_VERSION="3.10"

SHELL ["/bin/bash","-o","pipefail","-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8 \
    CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH \
    HF_HOME=/workspace/hf

WORKDIR /workspace
RUN mkdir -p /workspace "$HF_HOME" && chmod -R 777 /workspace "$HF_HOME"

# ===== System deps =====
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      git git-lfs curl wget ca-certificates tzdata locales \
      software-properties-common \
      build-essential pkg-config ninja-build \
      python3-distutils python3-apt \
    && git lfs install && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen && update-locale && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== Python ${PYTHON_VERSION} =====
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
      "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION}-venv" && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python && \
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && \
    python /tmp/get-pip.py && rm -f /tmp/get-pip.py && \
    python -m pip install --no-cache-dir -U pip setuptools wheel

# ===== PyTorch GPU (2.6.0 + cu126) =====
# 官方组合：torch 2.6.0 / torchvision 0.21.0 / torchaudio 2.6.0 + CUDA 12.6 :contentReference[oaicite:3]{index=3}
RUN python -m pip install --no-cache-dir \
    torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 \
    --index-url https://download.pytorch.org/whl/cu126

# ===== Verl + vLLM =====
# 官方文档推荐：pip install verl[vllm]，会拉一套兼容的 vLLM 版本 :contentReference[oaicite:4]{index=4}
RUN python -m pip install --no-cache-dir "verl[vllm]" && \
    python -m pip install --no-cache-dir \
      "huggingface_hub" "hf_transfer" "sentencepiece"

# ===== 快速自检：import verl / vllm / torch =====
RUN python - << 'PY'
import torch
import vllm
import verl

print("torch:", torch.__version__)
print("vllm:", vllm.__version__)
print("verl:", getattr(verl, "__version__", "unknown"))
PY

# 预留工作目录和环境变量，后面你起服务、跑训练都从这里开始就行
WORKDIR /workspace
ENV PYTHONUNBUFFERED=1

CMD ["/bin/bash"]
