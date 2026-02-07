\
# syntax=docker/dockerfile:1.7
# ===== GPU Runtime Layer =====
# 说明：
# - 文件名/职责抽象为“GPU 运行时能力”，不绑定 CUDA。
# - 未来如果不用 CUDA，直接替换 FROM 与相关 ENV 即可；上层 os/python/ml/runtime 不需要改。
# - 仍然保留 BASE_IMAGE 作为可配置入口（bake 里传参）。

ARG BASE_IMAGE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04"
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:$LD_LIBRARY_PATH

# CUDA bin convenience（仅当底层镜像有 /usr/local/cuda 时才生效）
RUN ln -sf /usr/local/cuda/bin/* /usr/bin/ || true
