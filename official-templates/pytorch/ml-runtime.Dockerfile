\
# syntax=docker/dockerfile:1.7
# ===== ML Runtime Layer =====
# 说明：PyTorch + Jupyter + NCCL tests（ML 相关能力集中在这里）

ARG BASE_IMAGE="base"
FROM ${BASE_IMAGE}

# PyTorch 2.9：这里用 nightly cu128（按你原来的方式）
ARG TORCH="torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128"
ARG NCCL_TESTS_VERSION="v2.13.11"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ===============================
# PyTorch (nightly cu128)
# ===============================
RUN python -m pip install --no-cache-dir ${TORCH}

# ===============================
# Jupyter + 常用 CLI（huggingface-cli / datasets-cli）
# ===============================
RUN python -m pip install --no-cache-dir \
      jupyterlab ipywidgets jupyter-archive notebook==7.3.3 \
      huggingface-hub datasets

# ===============================
# NCCL tests (build from source, force MPI=0 to avoid mpi.h missing)
# ===============================
RUN set -eux; \
    git clone --branch "${NCCL_TESTS_VERSION}" --depth 1 \
      https://github.com/NVIDIA/nccl-tests.git /opt/nccl-tests; \
    make -C /opt/nccl-tests -j"$(nproc)" MPI=0; \
    ln -sf /opt/nccl-tests/build/* /usr/local/bin/; \
    rm -rf /opt/nccl-tests/.git
